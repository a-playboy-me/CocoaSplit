//
//  CSInputSourceBase.h
//  CocoaSplit
//
//  Created by Zakk on 6/26/17.
//

#import <Foundation/Foundation.h>
#import "CSInputSourceProtocol.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "MIKMIDI.h"

@protocol CSInputSourceBaseJSExport <JSExport>
-(void)createUUID;
-(NSViewController *)configurationViewController;
-(void)afterAdd;
-(void)beforeDelete;
-(void)frameTick;
-(void)beforeMerge:(bool)changed;
-(void)afterMerge:(bool)changed;
-(void)beforeRemove;
-(void)beforeReplace:(bool)removing;
-(void)afterReplace;
@property (weak) SourceLayout *sourceLayout;
@property (strong) CSInputLayer *layer;
@property (assign) bool is_live;
@property (strong) NSString *name;
@property (strong) NSString *uuid;
@property (assign) NSInteger refCount;
@property (assign) bool active;
@property (readonly) NSImage *libraryImage;
@property (assign) float depth;
@property (strong) NSMutableArray *attachedInputs;
@property (assign) NSInteger scriptPriority;
@property (strong) NSString *script_afterAdd;
@property (strong) NSString *script_beforeDelete;
@property (strong) NSString *script_frameTick;
@property (strong) NSString *script_beforeMerge;
@property (strong) NSString *script_afterMerge;
@property (strong) NSString *script_beforeRemove;
@property (strong) NSString *script_beforeReplace;
@property (strong) NSString *script_afterReplace;

@property (assign) bool scriptAlwaysRun;
@property (assign) float duration;


@end

@interface CSInputSourceBase : NSObject <CSInputSourceProtocol, NSCoding, CSInputSourceBaseJSExport, NSCopying, MIKMIDIMappableResponder, MIKMIDIResponder>
{
    JSContext *_scriptContext;
}

@property (weak) SourceLayout *sourceLayout;
@property (strong) CSInputLayer *layer;
@property (assign) bool is_live;
@property (strong) NSString *name;
@property (strong) NSString *uuid;
@property (assign) NSInteger refCount;
@property (assign) bool active;
@property (readonly) NSImage *libraryImage;
@property (assign) float depth;
@property (strong) NSMutableArray *attachedInputs;
@property (assign) NSInteger scriptPriority;
@property (strong) NSString *script_afterAdd;
@property (strong) NSString *script_beforeDelete;
@property (strong) NSString *script_frameTick;
@property (strong) NSString *script_beforeMerge;
@property (strong) NSString *script_afterMerge;
@property (strong) NSString *script_beforeRemove;
@property (strong) NSString *script_beforeReplace;
@property (strong) NSString *script_afterReplace;

@property (assign) bool scriptAlwaysRun;
@property (assign) float duration;





@end
