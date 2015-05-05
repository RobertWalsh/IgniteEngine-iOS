//
//  IXSocketDataProvider.m
//  Ignite Engine
//
//  Created by Robert Walsh on 2/24/15.
//  Copyright (c) 2015 Apigee. All rights reserved.
//

#import "IXSocketDataProvider.h"
#import "JFRWebSocket.h"
#import "IXBaseDataProvider.h"
#import "IXDataRowDataProvider.h"
#import "NSString+IXAdditions.h"

// IXSocketDataProvider Attributes
IX_STATIC_CONST_STRING kIXLimit = @"limit";
IX_STATIC_CONST_INTEGER kIXDefaultLimit = -1;

// IXSocketDataProvider ReadOnly Attributes
IX_STATIC_CONST_STRING kIXIsOpen = @"isOpen";

// IXSocketDataProvider Functions
IX_STATIC_CONST_STRING kIXOpen = @"open";
IX_STATIC_CONST_STRING kIXClose = @"close";

// IXSocketDataProvider Events
IX_STATIC_CONST_STRING kIXOpened = @"opened";
IX_STATIC_CONST_STRING KIXClosed = @"closed";

IX_STATIC_CONST_STRING kIXDataDictionaryKey = @"data";

@interface JFRWebSocket ()
@property(nonatomic, strong)NSURL *url;
@end

@interface IXSocketDataProvider () <JFRWebSocketDelegate>

@property (nonatomic,strong) JFRWebSocket* webSocket;
@property (nonatomic,assign) NSInteger messageLimit;
@property (nonatomic,strong) NSMutableDictionary* messageDictionary;
@property (nonatomic,strong) NSString* responseString;
@property (nonatomic,strong) NSDictionary* responseObject;

@end

@implementation IXSocketDataProvider

-(void)dealloc
{
    if( [[self webSocket] isConnected] )
    {
        [[self webSocket] disconnect];
    }
}

-(instancetype)init
{
    self = [super init];
    if( self )
    {
        self.messageDictionary = [NSMutableDictionary dictionaryWithObject:[NSMutableArray array] forKey:kIXDataDictionaryKey];
    }
    return self;
}

-(void)loadData:(BOOL)forceGet
{
}

-(void)applySettings
{
    [super applySettings];

    [self setMessageLimit:[[self attributeContainer] getIntAttributeValue:kIXLimit defaultValue:kIXDefaultLimit]];
    if( [self webSocket] == nil || ![[[[self webSocket] url] absoluteString] isEqualToString:self.url ])
    {
        [[self webSocket] setDelegate:nil];
        [[self webSocket] disconnect];

        [self setWebSocket:[[JFRWebSocket alloc] initWithURL:[NSURL URLWithString:self.url] protocols:nil]];
        [[self webSocket] setDelegate:self];
    }

    if( [self shouldAutoLoad] )
    {
        [self.webSocket connect];
    }
}

-(void)websocket:(JFRWebSocket *)socket didReceiveMessage:(NSString *)string
{
    self.responseObject = _messageDictionary;
    [self setResponseString];
    
    NSMutableArray* messageArray = [[self messageDictionary] objectForKey:kIXDataDictionaryKey];
    id JSONObject = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    if( JSONObject != nil )
    {
        [messageArray insertObject:JSONObject atIndex:0];
        if( [self messageLimit] != -1 && [messageArray count] > [self messageLimit] )
        {
            [messageArray removeLastObject];
        }
        [self fireLoadFinishedEvents:YES];
    }
}

 -(void)setResponseString
{
    NSString* responseString = nil;
    NSData* jsonStringData = [NSJSONSerialization dataWithJSONObject:[self messageDictionary] options:0 error:nil];
    if( [jsonStringData length] > 0 )
    {
        responseString = [[NSString alloc] initWithData:jsonStringData encoding:NSUTF8StringEncoding];
    }
    self.responseString = responseString;
}

-(NSString *)getReadOnlyPropertyValue:(NSString *)propertyName
{
    NSString* returnValue = nil;
    if( [propertyName isEqualToString:kIXIsOpen] )
    {
        returnValue = [NSString ix_stringFromBOOL:[[self webSocket] isConnected]];
    }
    else
    {
        returnValue = [super getReadOnlyPropertyValue:propertyName];
    }
    return returnValue;
}

-(void)applyFunction:(NSString *)functionName withParameters:(IXAttributeContainer *)parameterContainer
{
    if( [functionName isEqualToString:kIXOpen] )
    {
        if( [self webSocket] && ![[self webSocket] isConnected] )
        {
            [[self webSocket] connect];
        }
    }
    else if( [functionName isEqualToString:kIXClose] )
    {
        if( [[self webSocket] isConnected] )
        {
            [[self webSocket] disconnect];
        }
    }
    else
    {
        [super applyFunction:functionName withParameters:parameterContainer];
    }
}

-(void)websocketDidConnect:(JFRWebSocket *)socket
{
    [[self actionContainer] executeActionsForEventNamed:kIXOpened];
}

-(void)websocketDidDisconnect:(JFRWebSocket *)socket error:(NSError *)error
{
    [[self actionContainer] executeActionsForEventNamed:KIXClosed];
}

@end
