//
//  IXSound.m
//  Ignite_iOS_Engine
//
//  Created by Robert Walsh on 2/11/14.
//  Copyright (c) 2014 Ignite. All rights reserved.
//

#import "IXAudioPlayer.h"

#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>
#import "IXViewController.h"

@import AVFoundation.AVPlayer;
@import AVFoundation.AVAudioSession;
@import AVFoundation.AVAsset;
@import AVFoundation;
@import AVFoundation.AVPlayerItem;


#import "IXAppManager.h"
#import "IXLogger.h"

#import "NSString+IXAdditions.h"

// Sound Properties
IX_STATIC_CONST_STRING kIXSoundLocation = @"audioUrl";
IX_STATIC_CONST_STRING kIXVolume = @"volume";
IX_STATIC_CONST_STRING kIXNumberOfLoops = @"repeatCount";
IX_STATIC_CONST_STRING kIXAutoPlay = @"autoPlay.enabled";
IX_STATIC_CONST_STRING kIXForceSoundReload = @"forceAudioReload.enabled";

// Sound Read-Only Properties
IX_STATIC_CONST_STRING kIXIsPlaying = @"isPlaying";
IX_STATIC_CONST_STRING kIXDuration = @"duration";
IX_STATIC_CONST_STRING kIXCurrentTime = @"now";

IX_STATIC_CONST_STRING kIXTimeDurationSeconds = @"time.duration.seconds";
IX_STATIC_CONST_STRING kIXTimeRemainingSeconds = @"time.remaining.seconds";
IX_STATIC_CONST_STRING kIXTimeElapsedSeconds = @"time.elapsed.seconds";

IX_STATIC_CONST_STRING kIXTimeDuration = @"time.duration";
IX_STATIC_CONST_STRING kIXTimeRemaining = @"time.remaining";
IX_STATIC_CONST_STRING kIXTimeElapsed = @"time.elapsed";

IX_STATIC_CONST_STRING kIXPodcastImage = @"podcast.image";

IX_STATIC_CONST_STRING kIXLastCreationError = @"error.message";

// Sound Events
IX_STATIC_CONST_STRING kIXFinished = @"done";
IX_STATIC_CONST_STRING kIXPlayPressed = @"play";
IX_STATIC_CONST_STRING kIXPausePressed = @"paused";
IX_STATIC_CONST_STRING kIXNextPressed = @"next";
IX_STATIC_CONST_STRING kIXPreviousPressed = @"previous";
IX_STATIC_CONST_STRING kIXStopPressed = @"stop";
IX_STATIC_CONST_STRING kIXProgress = @"progress";

// Sound Functions
IX_STATIC_CONST_STRING kIXPlay = @"play";
IX_STATIC_CONST_STRING kIXPause = @"pause";
IX_STATIC_CONST_STRING kIXStop = @"stop";
IX_STATIC_CONST_STRING kIXGoTo = @"goTo";

// IXMediaPlayer Function parameters
IX_STATIC_CONST_STRING kIXGoToSeconds = @"seconds";

@interface IXAudioPlayer ()

@property (nonatomic,strong) AVPlayer* player;
@property (nonatomic,strong) NSMutableDictionary *songInfo;
@property (nonatomic,strong) NSURL* lastSoundURL;
@property (nonatomic,strong) NSString* lastCreationErrorMessage;

@property (nonatomic,assign) BOOL forceSoundReload;
@property (nonatomic,assign) BOOL shouldAutoPlay;
@property (nonatomic,assign) float volume;
@property (nonatomic,assign) NSInteger numberOfLoops;

@end

@implementation IXAudioPlayer

-(void)dealloc
{
    [self unregisterForNotifications];
    [_player pause];
    if( [self songInfo] == [[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo]) {
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    }
}

-(void)buildView
{
    _songInfo = [NSMutableDictionary dictionary];

    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

    [self registerForNotifications];
}

-(void)registerForNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveRemoteControlEvent:)
                                                 name:IXViewControllerDidRecieveRemoteControlEventNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
}

-(void)unregisterForNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IXViewControllerDidRecieveRemoteControlEventNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
}

-(void)applySettings
{
    [super applySettings];

    [self setVolume:[[self propertyContainer] getFloatPropertyValue:kIXVolume defaultValue:1.0f]];
    [self setForceSoundReload:[[self propertyContainer] getBoolPropertyValue:kIXForceSoundReload defaultValue:NO]];
    if( [self player] ) {
        [[self player] setVolume:[self volume]];
    }

    NSURL* soundURL = [[self propertyContainer] getURLPathPropertyValue:kIXSoundLocation basePath:nil defaultValue:nil];
    if( ![[self lastSoundURL] isEqual:soundURL] || [self player] == nil || [self forceSoundReload] )
    {
        [self setLastSoundURL:soundURL];
        [self setShouldAutoPlay:[[self propertyContainer] getBoolPropertyValue:kIXAutoPlay defaultValue:YES]];
        [self setNumberOfLoops:[[self propertyContainer] getIntPropertyValue:kIXNumberOfLoops defaultValue:0]];
        [self setLastCreationErrorMessage:nil];

        [self createAudioPlayer];
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [[[self player] currentItem] seekToTime:kCMTimeZero];
    [self pause];
    [[self actionContainer] executeActionsForEventNamed:kIXFinished];
    if( [self numberOfLoops] < 0 ) {
        [self play];
    } else if( [self numberOfLoops] > 0 ) {
        [self play];
        self.numberOfLoops--;
    }
}

-(void)didReceiveRemoteControlEvent:(NSNotification*)notification
{
    UIEvent* remoteControlEvent = [notification userInfo][IXViewControllerRemoteControlEventNotificationUserInfoEventKey];
    if (remoteControlEvent.type == UIEventTypeRemoteControl) {
        switch (remoteControlEvent.subtype) {
            case UIEventSubtypeRemoteControlPlay:{
                [self play];
                [[self actionContainer] executeActionsForEventNamed:kIXPlayPressed];
                break;
            }
            case UIEventSubtypeRemoteControlPause:
                [self pause];
                [[self actionContainer] executeActionsForEventNamed:kIXPausePressed];
                break;
            case UIEventSubtypeRemoteControlTogglePlayPause:
                if ([self isPlaying]) {
                    [self pause];
                    [[self actionContainer] executeActionsForEventNamed:kIXPausePressed];
                } else {
                    [self play];
                    [[self actionContainer] executeActionsForEventNamed:kIXPlayPressed];
                }
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                [[self actionContainer] executeActionsForEventNamed:kIXNextPressed];
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
                [[self actionContainer] executeActionsForEventNamed:kIXPreviousPressed];
                break;
            case UIEventSubtypeRemoteControlStop:
                [self pause];
                [[self actionContainer] executeActionsForEventNamed:kIXPausePressed];
                break;
            case UIEventSubtypeRemoteControlBeginSeekingBackward:
            case UIEventSubtypeRemoteControlBeginSeekingForward:
            case UIEventSubtypeRemoteControlEndSeekingBackward:
            case UIEventSubtypeRemoteControlEndSeekingForward:
            default:
                break;
        }
    }
}

-(void)applyFunction:(NSString *)functionName withParameters:(IXPropertyContainer *)parameterContainer
{
    if( [functionName isEqualToString:kIXPlay] )
    {
        [self play];
    }
    else if( [functionName isEqualToString:kIXPause] )
    {
        [self pause];
    }
    else if( [functionName isEqualToString:kIXStop] )
    {
        [self pause];
    }
    else if( [functionName compare:kIXGoTo] == NSOrderedSame )
    {
        [self seekToTime:[parameterContainer getFloatPropertyValue:kIXGoToSeconds defaultValue:CMTimeGetSeconds(_player.currentTime)]];
    }
    else
    {
        [super applyFunction:functionName withParameters:parameterContainer];
    }
}

-(void)play {
    if( ![self isPlaying] ) {
        [[self player] play];
        [[self player] setRate:1];
        [[self songInfo] setObject:[NSNumber numberWithDouble:CMTimeGetSeconds([self player].currentItem.asset.duration)] forKey:MPMediaItemPropertyPlaybackDuration];
        [[self songInfo] setObject:[NSNumber numberWithInt:1] forKey:MPNowPlayingInfoPropertyPlaybackRate];
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:[self songInfo]];
    }
}

-(void)pause {
    [[self player] pause];
    [[self songInfo] setObject:[NSNumber numberWithDouble:CMTimeGetSeconds([[self player] currentTime])] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [[self songInfo] setObject:[NSNumber numberWithInt:0] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:[self songInfo]];
}

-(void)seekToTime:(CGFloat)seconds {
    CMTime timeWithSeconds = CMTimeMakeWithSeconds(seconds, [[self player] currentTime].timescale);
    [[self player] seekToTime:timeWithSeconds];
    [[self songInfo] setObject:[NSNumber numberWithDouble:CMTimeGetSeconds([[self player] currentTime])] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:[self songInfo]];
}

- (BOOL)isPlaying {
    return ([[self player] rate] > 0 && ![[self player] error]);
}

-(NSString*)getReadOnlyPropertyValue:(NSString *)propertyName
{
    NSString* returnValue = nil;
    if( [propertyName isEqualToString:kIXIsPlaying] )
    {
        returnValue = [NSString ix_stringFromBOOL:[self isPlaying]];
    }
    else if( [propertyName isEqualToString:kIXDuration] )
    {
        returnValue = [NSString ix_stringFromFloat:CMTimeGetSeconds([self player].currentItem.asset.duration)];
    }

    else if( [propertyName isEqualToString:kIXCurrentTime] )
    {
        returnValue = [NSString ix_stringFromFloat:CMTimeGetSeconds([self player].currentTime)];
    }

    else if( [propertyName isEqualToString:kIXTimeDurationSeconds] )
    {
        returnValue = [NSString ix_stringFromFloat:CMTimeGetSeconds([self player].currentItem.asset.duration)];
    }
    else if( [propertyName isEqualToString:kIXTimeElapsedSeconds] )
    {
        returnValue = [NSString ix_stringFromFloat:CMTimeGetSeconds([self player].currentTime)];
    }
    else if( [propertyName isEqualToString:kIXTimeRemainingSeconds] )
    {
        NSInteger duration = CMTimeGetSeconds([self player].currentItem.asset.duration);
        NSInteger elapsed = CMTimeGetSeconds([self player].currentTime);
        NSInteger remaining = duration - elapsed;
        returnValue = [NSString ix_stringFromFloat:remaining];
    }
    else if( [propertyName isEqualToString:kIXTimeDuration] )
    {
        NSInteger duration = CMTimeGetSeconds([self player].currentItem.asset.duration);
        return [self timeFormatted:duration];
    }
    else if( [propertyName isEqualToString:kIXTimeElapsed] )
    {
        NSInteger currentTime = (NSInteger)CMTimeGetSeconds([self player].currentTime);
        return [self timeFormatted:currentTime];
    }
    else if( [propertyName isEqualToString:kIXTimeRemaining] )
    {
        NSInteger currentTime = (NSInteger)CMTimeGetSeconds([self player].currentTime);
        NSInteger duration = (NSInteger)CMTimeGetSeconds([self player].currentItem.asset.duration);
        NSInteger remainingTime = duration - currentTime;
        return [self timeFormatted:remainingTime];
    }
    else if( [propertyName isEqualToString:kIXLastCreationError] )
    {
        returnValue = [self lastCreationErrorMessage];
    }
    else
    {
        returnValue = [super getReadOnlyPropertyValue:propertyName];
    }
    return returnValue;
}

-(void)createAudioPlayer
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        [self pause];

        _player = [[AVPlayer alloc] initWithURL:[self lastSoundURL]];

        if( [self player] && ![[self player] error] )
        {
            AVPlayerItem *playerItem = [[self player] currentItem];
            NSArray *metadataList = [[playerItem asset] commonMetadata];
            for (AVMetadataItem *metaItem in metadataList) {
                if( [[metaItem commonKey] isEqualToString:AVMetadataCommonKeyTitle] ) {
                    [[self songInfo] setObject:[metaItem value] forKey:MPMediaItemPropertyTitle];
                } else if( [[metaItem commonKey] isEqualToString:AVMetadataCommonKeyArtist] ) {
                    [[self songInfo] setObject:[metaItem value] forKey:MPMediaItemPropertyArtist];
                } else if( [[metaItem commonKey] isEqualToString:AVMetadataCommonKeyAlbumName] ) {
                    [[self songInfo] setObject:[metaItem value] forKey:MPMediaItemPropertyAlbumTitle];
                } else if( [[metaItem commonKey] isEqualToString:AVMetadataCommonKeyArtwork] ) {
                    id value = [metaItem value];
                    if( [value isKindOfClass:[NSData class]] ) {
                        UIImage* image = [UIImage imageWithData:(NSData*)value];
                        if( image ) {
                            [[self songInfo] setObject:[[MPMediaItemArtwork alloc]initWithImage:image] forKey:MPMediaItemPropertyArtwork];
                        }
                    }
                }
            }

            [[self songInfo] setObject:[NSNumber numberWithDouble:CMTimeGetSeconds([[playerItem asset] duration])] forKey:MPMediaItemPropertyPlaybackDuration];
            [[self songInfo] setObject:[NSNumber numberWithDouble:CMTimeGetSeconds([[self player] currentTime])] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
            [[self songInfo] setObject:[NSNumber numberWithInt:0] forKey:MPNowPlayingInfoPropertyPlaybackRate];
            [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:[self songInfo]];

            [[self player] setVolume:[self volume]];
            [[self player] addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0 / 60.0, NSEC_PER_SEC)
                                                        queue:NULL
                                                   usingBlock:^(CMTime time){
                                                       [[self actionContainer] executeActionsForEventNamed:kIXProgress];
                                                   }];
        }
        else
        {
            if( _player.error )
            {
                [self setLastCreationErrorMessage:[_player.error description]];
            }

            IX_LOG_ERROR(@"ERROR: from %@ in %@ : SOUND CONTROL ID:%@ CREATION ERROR: %@",THIS_FILE,THIS_METHOD,[[self ID] uppercaseString],[self lastCreationErrorMessage]);
        }

        IX_dispatch_main_sync_safe(^{
            if( [self shouldAutoPlay] && ![self isPlaying] )
            {
                [self play];
            }
        });
    });
}

- (NSString *)timeFormatted:(NSInteger)totalSeconds
{
    NSInteger seconds = totalSeconds % 60;
    NSInteger minutes = (totalSeconds / 60) % 60;
    NSInteger hours = totalSeconds / 3600;

    NSString* returnString;
    if( hours > 0 )
    {
        returnString = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)hours, (long)minutes, (long)seconds];
    }
    else
    {
        returnString = [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)seconds];
    }
    
    return returnString;
}

@end