//
//  CSFFMpegPlayer.m
//  CSFFMpegCapturePlugin
//
//  Created by Zakk on 6/17/16.
//  Copyright © 2016 Zakk. All rights reserved.
//

#import "CSFFMpegPlayer.h"

@implementation CSFFMpegPlayer


-(instancetype) init
{
    if (self = [super init])
    {
        _input_read_queue = dispatch_queue_create("FFMPEG PLAYER INPUT", DISPATCH_QUEUE_SERIAL);
        _audio_queue = dispatch_queue_create("FFMPEG PLAYER AUDIO", DISPATCH_QUEUE_SERIAL);
        _currentSize = NSZeroSize;
        _inputQueue = [[NSMutableArray alloc] init];
        _nextFlag = NO;
        _muted = NO;
        
    }
    
    return self;
}


-(void)removeObjectFromInputQueueAtIndex:(NSUInteger)index
{
    [_inputQueue removeObjectAtIndex:index];
}

-(void)insertObject:(NSObject *)object inInputQueueAtIndex:(NSUInteger)index
{
    [_inputQueue insertObject:object atIndex:index];
}



-(void)readThread
{
        if (self.currentlyPlaying)
        {
            [self.currentlyPlaying readAndDecodeVideoFrames:0];
        }
}


-(void)nextItem
{
    
    CSFFMpegInput *useItem;
    _nextFlag = NO;
    @synchronized (self) {
        useItem = self.currentlyPlaying;
        self.currentlyPlaying = nil;
        _audio_done = NO;
        _video_done = NO;
        _first_frame_host_time = 0;
    }
    
    if (useItem)
    {
        if (self.pcmPlayer)
        {
            [self.pcmPlayer flush];
        }
    }
    
    if (!self.playing)
    {
        return;
    }

    CSFFMpegInput *nextItem = _inputQueue.firstObject;
    if (nextItem)
    {
        [self playItem:nextItem];
        [self removeObjectFromInputQueueAtIndex:0];
        
    }
    
}


-(void)seek:(double)toTime
{
    if (self.currentlyPlaying)
    {
        [self.currentlyPlaying seek:toTime];
        _first_frame_host_time = CACurrentMediaTime();
        _peek_frame = NULL;
    }
}


-(void)playItem:(CSFFMpegInput *)item
{
    dispatch_async(_input_read_queue, ^{
        
        [item openMedia:15];
        
        if (self.itemStarted)
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ self.itemStarted(item);});
        }

        self.lastVideoTime = 0.0f;
        self.videoDuration = item.duration;
        
        
        @synchronized (self) {
            self.currentlyPlaying = item;
            self.playing = YES;
        }
        [self readThread];
    });
}


-(void)enqueueItem:(CSFFMpegInput *)item
{
    [self insertObject:item inInputQueueAtIndex:self.inputQueue.count];
    
}


-(void)play
{
    self.playing = YES;
    if (!self.currentlyPlaying)
    {

            [self nextItem];
        
    }
}

-(void)next
{
    [self.currentlyPlaying stop];
    
}

-(void)stop
{
    self.playing = NO;
    [self.currentlyPlaying closeMedia];
}

-(void)startAudio
{
    dispatch_async(_audio_queue, ^{
        [self.pcmPlayer play];
        [self audioThread];
    });
}



-(void)audioThread
{
    int av_error = 0;
    CAMultiAudioPCM *audioPCM = NULL;
    CSFFMpegInput *useItem;
    bool good_audio = NO;
    
    while (self.playing && (audioPCM = [self.currentlyPlaying consumeAudioFrame:self.asbd error_out:&av_error]))
    {

        if (!self.playing) break;
        if (av_error == AVERROR_EOF)
        {
            break;
        }
    
        if (audioPCM.bufferCount == -1 && audioPCM.frameCount == -1)
        {
            if (good_audio)
            {
            //input needs us to flush the player, probably due to seek
            [self.pcmPlayer flush];
            return;
            } else {
                continue;
            }
        }
        
        good_audio = YES;
    
        if (self.muted)
        {
            continue;
        }
        if (!self.playing) break;
        
        if (self.pcmPlayer.pendingFrames > 60)
        {
            usleep(10000);
        }
        
        if (!self.playing) break;
        [self.pcmPlayer playPcmBuffer:audioPCM];
        
        if (!self.playing) break;
    }
    
    _audio_done = YES;
    [self inputDone];
}




-(CVPixelBufferRef)frameForMediaTime:(CFTimeInterval)mediaTime
{
    CSFFMpegInput *_useInput;
    
    @synchronized (self) {
         _useInput = self.currentlyPlaying;
    }
    
    if (!_useInput)
    {
        return nil;
    }
    
    /*
    if (!self.playing)
    {
        return nil;
    }*/
    
    
    AVFrame *use_frame = NULL;
    CVPixelBufferRef ret = nil;
    int64_t audio_pts = 0;
    bool play_audio = YES;
    
    
    int av_error = 0;
    
    if (_first_frame_host_time == 0)
    {
        
        play_audio = NO;
        
        use_frame = [_useInput consumeFrame:&av_error];
        if (use_frame)
        {
            
            _first_frame_host_time = mediaTime;
            _peek_frame = NULL;
            _last_buf = nil;
            audio_pts = use_frame->pkt_pts;
            [self startAudio];
        }
    } else {
        CFTimeInterval host_delta = mediaTime - _first_frame_host_time;
        int64_t target_pts = host_delta / av_q2d(self.currentlyPlaying.videoTimeBase);
        target_pts += self.currentlyPlaying.first_video_pts;
        
        audio_pts = target_pts;
        
        
        
        int consumed = 0;
        use_frame = NULL;
        bool do_consume = YES;
        
        if (_last_buf && _peek_frame)
        {
            
            if (_peek_frame->pkt_pts > target_pts)
            {
                do_consume = NO;
            } else {
                use_frame = _peek_frame;
                do_consume = YES;
            }
        }
        
        while (do_consume && (_peek_frame = [_useInput consumeFrame:&av_error]) && _peek_frame->pkt_pts < target_pts)
        {
            
            if (use_frame)
            {
                av_frame_free(&use_frame);
                use_frame = _peek_frame;
            }
            consumed++;
        }
        if (av_error == AVERROR_EOF)
        {
            _video_done = YES;
        }

        consumed++;
    }
    if (use_frame && !_video_done)
    {
        if (self.audio_needs_restart)
        {
            [self startAudio];
            self.audio_needs_restart = NO;
        }
        
        self.lastVideoTime = use_frame->pkt_pts * av_q2d(_useInput.videoTimeBase);
        
        ret = [self convertFrameToPixelBuffer:use_frame];
        av_frame_free(&use_frame);
        CVPixelBufferRetain(ret);
        if (_last_buf)
        {
            CVPixelBufferRelease(_last_buf);
        }
        _last_buf = ret;
    } else {
        CVPixelBufferRetain(_last_buf);
        ret = _last_buf;
    }
    
    [self inputDone];
    return ret;
}

-(void)inputDone
{
    if (_audio_done && _video_done)
    {
        [self.currentlyPlaying stop];
        
            [self nextItem];
    }
}


-(bool) createPixelBufferPoolForSize:(NSSize) size
{
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setValue:[NSNumber numberWithInt:size.width] forKey:(NSString *)kCVPixelBufferWidthKey];
    [attributes setValue:[NSNumber numberWithInt:size.height] forKey:(NSString *)kCVPixelBufferHeightKey];
    [attributes setValue:@{(NSString *)kIOSurfaceIsGlobal: @NO} forKey:(NSString *)kCVPixelBufferIOSurfacePropertiesKey];
    [attributes setValue:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    
    
    
    if (_cvpool)
    {
        CVPixelBufferPoolRelease(_cvpool);
    }
    
    
    
    CVReturn result = CVPixelBufferPoolCreate(NULL, NULL, (__bridge CFDictionaryRef)(attributes), &_cvpool);
    
    if (result != kCVReturnSuccess)
    {
        return NO;
    }
    
    return YES;
    
    
}

-(CVPixelBufferRef) convertFrameToPixelBuffer:(AVFrame *)av_frame
{
    if (!av_frame || !av_frame->data[0])
    {
        return nil;
    }
    
    
    if (av_frame->linesize[1] != av_frame->linesize[2])
    {
        return nil;
    }
    
    NSSize frameSize = NSMakeSize(av_frame->width, av_frame->height);
    if (!NSEqualSizes(_currentSize, frameSize))
    {
        _currentSize = frameSize;
        [self createPixelBufferPoolForSize:frameSize];
    }
    
    
    CVPixelBufferRef buf;
    CVPixelBufferPoolCreatePixelBuffer(NULL, _cvpool, &buf);
    
    size_t plane_size = av_frame->linesize[1]*av_frame->height/2;
    size_t dst_plane_size = plane_size*2;
    uint8_t *dst_plane = malloc(dst_plane_size);
    for (size_t i = 0; i < plane_size; i++)
    {
        dst_plane[2*i] = av_frame->data[1][i];
        dst_plane[2*i+1] = av_frame->data[2][i];
    }
    
    size_t bytePerRowY = CVPixelBufferGetBytesPerRowOfPlane(buf, 0);
    size_t bytesPerRowUV = CVPixelBufferGetBytesPerRowOfPlane(buf, 1);
    
    CVPixelBufferLockBaseAddress(buf, 0);
    
    void* base =  CVPixelBufferGetBaseAddressOfPlane(buf, 0);
    memcpy(base, av_frame->data[0], bytePerRowY*av_frame->height);
    
    base = CVPixelBufferGetBaseAddressOfPlane(buf, 1);
    memcpy(base, dst_plane, bytesPerRowUV*av_frame->height/2);
    
    
    CVPixelBufferUnlockBaseAddress(buf, 0);
    
    free(dst_plane);
    
    return buf;
}


@end