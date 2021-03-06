//
//  CSSequenceItemLayout.h
//  CocoaSplit
//
//  Created by Zakk on 3/11/17.
//  Copyright © 2017 Zakk. All rights reserved.
//

#import "CSSequenceItem.h"
#import "SourceLayout.h"

typedef enum layout_sequence_type_t {
    kCSLayoutSequenceSwitch = 0,
    kCSLayoutSequenceMerge = 1,
    kCSLayoutSequenceRemove = 2
} layout_sequence_type;


@interface CSSequenceItemLayout : CSSequenceItem


@property (assign) layout_sequence_type actionType;
@property (strong) NSString *layoutName;


-(instancetype) initWithLayoutName:(NSString *)layoutName;

@end
