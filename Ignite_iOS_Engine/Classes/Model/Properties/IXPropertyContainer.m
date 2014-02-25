//
//  IXPropertyBag.m
//  Ignite iOS Engine (IX)
//
//  Created by Robert Walsh on 10/7/13.
//  Copyright (c) 2013 Apigee, Inc. All rights reserved.
//

#import "IXPropertyContainer.h"

#import "IXAppManager.h"
#import "IXSandbox.h"
#import "IXProperty.h"
#import "IXControlLayoutInfo.h"

#import "IXBaseObject.h"
#import "ColorUtils.h"
#import "SDWebImageManager.h"
#import "UIImage+IXAdditions.h"

@interface IXPropertyContainer ()

@property (nonatomic,strong) NSMutableDictionary* propertiesDict;

@end

@implementation IXPropertyContainer

-(instancetype)init
{
    self = [super init];
    if( self )
    {
        _ownerObject = nil;
        _propertiesDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(instancetype)copyWithZone:(NSZone *)zone
{
    IXPropertyContainer* propertyContainerCopy = [[[self class] allocWithZone:zone] init];
    [propertyContainerCopy setOwnerObject:[self ownerObject]];
    [[self propertiesDict] enumerateKeysAndObjectsUsingBlock:^(NSString* propertyName, NSArray* propertyArray, BOOL *stop) {
        NSMutableArray* propertyArrayCopy = [[NSMutableArray alloc] initWithArray:propertyArray copyItems:YES];
        [propertyContainerCopy addProperties:propertyArrayCopy];
    }];
    return propertyContainerCopy;
}

-(NSMutableArray*)propertiesForPropertyNamed:(NSString*)propertyName
{
    return [self propertiesDict][propertyName];
}

-(BOOL)propertyExistsForPropertyNamed:(NSString*)propertyName
{
    return ([self getPropertyToEvaluate:propertyName] != nil);
}

-(void)addProperties:(NSArray*)properties
{
    [self addProperties:properties replaceOtherPropertiesWithTheSameName:NO];
}

-(void)addProperties:(NSArray*)properties replaceOtherPropertiesWithTheSameName:(BOOL)replaceOtherProperties
{
    for( IXProperty* property in properties )
    {
        [self addProperty:property replaceOtherPropertiesWithTheSameName:replaceOtherProperties];
    }
}

-(void)addProperty:(IXProperty*)property
{
    [self addProperty:property replaceOtherPropertiesWithTheSameName:NO];
}

-(void)addProperty:(IXProperty*)property replaceOtherPropertiesWithTheSameName:(BOOL)replaceOtherProperties
{
    NSString* propertyName = [property propertyName];
    if( property == nil || propertyName == nil )
    {
        NSLog(@"ERROR: TRYING TO ADD PROPERTY THAT IS NIL OR PROPERTIES NAME IS NIL");
        return;
    }
    
    [property setPropertyContainer:self];
    
    NSMutableArray* propertyArray = [self propertiesForPropertyNamed:propertyName];
    if( propertyArray == nil )
    {
        propertyArray = [[NSMutableArray alloc] initWithObjects:property, nil];
        [[self propertiesDict] setObject:propertyArray forKey:propertyName];
    }
    else if( replaceOtherProperties )
    {
        [propertyArray removeAllObjects];
        [propertyArray addObject:property];
    }
    else if( ![propertyArray containsObject:property] )
    {
        [propertyArray addObject:property];
    }
}

-(BOOL)hasLayoutProperties
{
    BOOL hasLayoutProperties = NO;
    for( NSString* propertyName in [[self propertiesDict] allKeys] )
    {
        hasLayoutProperties = [IXControlLayoutInfo doesPropertyNameTriggerLayout:propertyName];
        if( hasLayoutProperties )
            break;
    }
    return hasLayoutProperties;
}

-(void)addPropertiesFromPropertyContainer:(IXPropertyContainer*)propertyContainer evaluateBeforeAdding:(BOOL)evaluateBeforeAdding replaceOtherPropertiesWithTheSameName:(BOOL)replaceOtherProperties
{
    NSArray* propertyNames = [[propertyContainer propertiesDict] allKeys];
    for( NSString* propertyName in propertyNames )
    {
        if( evaluateBeforeAdding )
        {
            NSString* propertyValue = [propertyContainer getStringPropertyValue:propertyName defaultValue:nil];
            if( propertyValue )
            {
                IXProperty* property = [[IXProperty alloc] initWithPropertyName:propertyName rawValue:propertyValue];
                [self addProperty:property replaceOtherPropertiesWithTheSameName:replaceOtherProperties];
            }
        }
        else
        {
            NSArray* propertyArray = [propertyContainer propertiesForPropertyNamed:propertyName];
            for( IXProperty* property in propertyArray )
            {
                [property setPropertyContainer:self];
            }
            [[self propertiesDict] setObject:propertyArray forKey:propertyName];
        }
    }
}

-(NSDictionary*)getAllPropertiesStringValues
{
    NSMutableDictionary* returnDictionary = [[NSMutableDictionary alloc] init];
    
    NSArray* propertyNames = [[self propertiesDict] allKeys];
    for( NSString* propertyName in propertyNames )
    {
        NSString* propertyValue = [self getStringPropertyValue:propertyName defaultValue:@""];
        
        [returnDictionary setObject:propertyValue forKey:propertyName];
    }
    
    return returnDictionary;
}

-(IXProperty*)getPropertyToEvaluate:(NSString*)propertyName
{
    if( propertyName == nil )
        return nil;
    
    IXProperty* propertyToEvaluate = nil;
    NSArray* propertyArray = [self propertiesForPropertyNamed:propertyName];
    if( propertyArray != nil || [propertyArray count] > 0 )
    {
        UIInterfaceOrientation currentOrientation = [IXAppManager currentInterfaceOrientation];
        for( IXProperty* property in [[propertyArray reverseObjectEnumerator] allObjects] )
        {
            if( [property areConditionalAndOrientationMaskValid:currentOrientation] )
            {
                propertyToEvaluate = property;
                break;
            }
        }
    }
    return propertyToEvaluate;
}

-(NSString*)getStringPropertyValue:(NSString*)propertyName defaultValue:(NSString*)defaultValue
{
    IXProperty* propertyToEvaluate = [self getPropertyToEvaluate:propertyName];
    NSString* returnValue =  ( propertyToEvaluate != nil ) ? [propertyToEvaluate getPropertyValue] : defaultValue;
    return returnValue;
}

-(NSArray*)getCommaSeperatedArrayListValue:(NSString*)propertyName defaultValue:(NSArray*)defaultValue
{
    NSArray* returnArray = defaultValue;
    NSString* stringValue = [self getStringPropertyValue:propertyName defaultValue:nil];
    if( stringValue != nil )
    {
        returnArray = [stringValue componentsSeparatedByString:@","];
    }
    return returnArray;
}

-(BOOL)getBoolPropertyValue:(NSString*)propertyName defaultValue:(BOOL)defaultValue
{
    NSString* stringValue = [self getStringPropertyValue:propertyName defaultValue:nil];
    BOOL returnValue =  ( stringValue != nil ) ? [stringValue boolValue] : defaultValue;
    return returnValue;
}

-(int)getIntPropertyValue:(NSString*)propertyName defaultValue:(int)defaultValue
{
    NSString* stringValue = [self getStringPropertyValue:propertyName defaultValue:nil];
    int returnValue =  ( stringValue != nil ) ? (int) [stringValue integerValue] : defaultValue;
    return returnValue;
}

-(float)getFloatPropertyValue:(NSString*)propertyName defaultValue:(float)defaultValue
{
    NSString* stringValue = [self getStringPropertyValue:propertyName defaultValue:nil];
    float returnValue =  ( stringValue != nil ) ? [stringValue floatValue] : defaultValue;
    return returnValue;
}

-(float)getSizeValue:(NSString*)propertyName maximumSize:(float)maxSize defaultValue:(float)defaultValue
{
    IXSizePercentageContainer* sizePercentageContainer = [self getSizePercentageContainer:propertyName defaultValue:defaultValue];
    float returnValue = [sizePercentageContainer evaluteForMaxValue:maxSize];
    return returnValue;
}

-(IXSizePercentageContainer*)getSizePercentageContainer:(NSString*)propertyName defaultValue:(CGFloat)defaultValue
{
    NSString* stringValue = [self getStringPropertyValue:propertyName defaultValue:nil];
    return [IXSizePercentageContainer sizeAndPercentageContainerWithStringValue:stringValue orDefaultValue:defaultValue];
}

-(UIColor*)getColorPropertyValue:(NSString*)propertyName defaultValue:(UIColor*)defaultValue
{
    NSString* stringValue = [self getStringPropertyValue:propertyName defaultValue:nil];
    UIColor* returnValue =  ( stringValue != nil ) ? [UIColor colorWithString:stringValue] : defaultValue;
    return returnValue;
}

-(void)getImageProperty:(NSString*)propertyName successBlock:(IXPropertyContainerImageSuccessCompletedBlock)successBlock failBlock:(IXPropertyContainerImageFailedCompletedBlock)failBlock
{
    NSString* imagePath = [self getPathPropertyValue:propertyName basePath:nil defaultValue:nil];
    /*
     Added in a fallback so that if images.touch (etc.) don't exist, it tries again with "images.default".
     This way we don't have to specify several of the same image in the JSON.
     - B
    */
    if( imagePath == nil )
    {
        imagePath = [self getPathPropertyValue:@"images.default" basePath:nil defaultValue:nil];
    }
    if( imagePath != nil )
    {
        NSURL *imageURL = nil;
        if( [IXAppManager pathIsAssetsLibrary:imagePath] )
        {
            ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
            [assetLibrary assetForURL:[NSURL fileURLWithPath:imagePath] resultBlock:^(ALAsset *asset)
             {
                 ALAssetRepresentation *rep = [asset defaultRepresentation];
                 Byte *buffer = (Byte*)malloc(rep.size);
                 NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
                 NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
             }
             failureBlock:^(NSError *err) {
                 NSLog(@"Error: %@",[err localizedDescription]);
             }];
        }
        else if( [IXAppManager pathIsLocal:imagePath] )
        {
            imageURL = [NSURL fileURLWithPath:imagePath];
            
            UIImage* image = [[[SDWebImageManager sharedManager] imageCache] imageFromMemoryCacheForKey:[imageURL absoluteString]];
            if( image )
            {
                if( successBlock )
                {
                    successBlock(image);
                    return;
                }
            }            
        }
        else
        {
            imageURL = [NSURL URLWithString:imagePath];
        }
        
        if([[imagePath pathExtension] isEqualToString:@"gif"])
        {
            float gifDuration = [self getFloatPropertyValue:@"gif_duration" defaultValue:1.0f];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData* data = [[NSData alloc] initWithContentsOfFile:imagePath];
                UIImage* returnImage = [UIImage ix_animatedGIFWithData:data withDuration:gifDuration];
                dispatch_main_sync_safe(^{
                    if( returnImage && successBlock != nil )
                    {
                        successBlock([UIImage imageWithCGImage:[returnImage CGImage]]);
                    }
                    else if( failBlock != nil )
                    {
                        failBlock(nil);
                    }
                });
            });
            
            return;
        }
        
        if( imageURL )
        {
            [[SDWebImageManager sharedManager] downloadWithURL:imageURL
                                                       options:SDWebImageCacheMemoryOnly
                                                      progress:nil
                                                     completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished){
                                                         if (image) {
                                                             if( successBlock )
                                                                successBlock([UIImage imageWithCGImage:[image CGImage]]);
                                                         } else {
                                                             if( failBlock )
                                                                failBlock(error);
                                                         }
                                                     }];
        }
    }
    else
    {
        if( failBlock != nil )
        {
            failBlock(nil);
        }
    }
}

-(NSURL*)getURLPathPropertyValue:(NSString*)propertyName basePath:(NSString*)basePath defaultValue:(NSURL*)defaultValue
{
    NSURL* returnURL = nil;
    NSString* path = [self getPathPropertyValue:propertyName basePath:basePath defaultValue:[defaultValue absoluteString]];
    if( path )
    {
        if( [IXAppManager pathIsLocal:path] )
        {
            returnURL = [NSURL fileURLWithPath:path];
        }
        else
        {
            returnURL = [NSURL URLWithString:path];
        }
    }    
    return returnURL;
}

-(NSString*)getPathPropertyValue:(NSString*)propertyName basePath:(NSString*)basePath defaultValue:(NSString*)defaultValue
{
    // Use this to get IMAGE paths. Then set up a image loader singleton that loads all the images for you.
    // Same with other FILE paths. When a control needs the data from a file use this to get the path to the image and set up a data loader singleton.
    
    NSString* returnPath = defaultValue;
    NSString* pathStringSetting = [self getStringPropertyValue:propertyName defaultValue:defaultValue];
    if( pathStringSetting != nil && ![pathStringSetting isEqualToString:@"(null)"])
    {
        if( ![IXAppManager pathIsLocal:pathStringSetting] || [IXAppManager pathIsAssetsLibrary:pathStringSetting])
        {
            returnPath = pathStringSetting;
        }
        else if( basePath == nil )
        {
            NSString* rootPath = [[[self ownerObject] sandbox] rootPath];
            if( [pathStringSetting hasPrefix:@"/"] )
            {
                returnPath = [NSString stringWithFormat:@"%@%@",rootPath,pathStringSetting];
            }
            else
            {
                returnPath = [NSString stringWithFormat:@"%@/%@",rootPath,pathStringSetting];
            }
        }
        else
        {
            returnPath = [NSString stringWithFormat:@"%@/%@",basePath,pathStringSetting];
        }
    }
    return returnPath;
}

-(UIFont*)getFontPropertyValue:(NSString*)propertyName defaultValue:(UIFont*)defaultValue
{
    UIFont* returnFont = defaultValue;
    NSString* stringValue = [self getStringPropertyValue:propertyName defaultValue:nil];
    if( stringValue )
    {
        NSArray* fontComponents = [stringValue componentsSeparatedByString:@":"];
        
        NSString* fontName = [fontComponents firstObject];
        CGFloat fontSize = [[fontComponents lastObject] floatValue];
        
        if( fontName )
        {
            returnFont = [UIFont fontWithName:fontName size:fontSize];
        }
    }
    return returnFont;
}

-(NSString*)description
{
    NSMutableString* description = [NSMutableString string];
    NSArray* properties = [[self propertiesDict] allKeys];
    for( NSString* propertyKey in properties )
    {
        IXProperty* propertyToEvaluate = [self getPropertyToEvaluate:propertyKey];
        [description appendFormat:@"\t%@: %@",propertyKey, [propertyToEvaluate getPropertyValue]];
        if( [propertyToEvaluate shortCodes] )
        {
            [description appendFormat:@" (%@)",[propertyToEvaluate originalString]];
        }
        [description appendString:@"\n"];
    }
    return description;
}

@end
