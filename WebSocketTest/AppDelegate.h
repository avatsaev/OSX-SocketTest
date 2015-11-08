//
//  AppDelegate.h
//  WebSocketTest
//
//  Created by A. Vatsaev on 09/12/2013.
//  Copyright (c) 2013 Vatsaev Aslan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCDAsyncSocket.h"


@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDelegate, GCDAsyncSocketDelegate>{
    dispatch_queue_t socketQueue;
	GCDAsyncSocket *listenSocket;
    int port;
	NSMutableArray *connectedSockets;
    NSMutableArray *connectedClients;
}

@property (assign) IBOutlet NSWindow *window;


//1: on
//0: off
@property int status;

- (IBAction)startServ:(id)sender;
- (IBAction)stopServ:(id)sender;
- (IBAction)pingClient:(id)sender;

@property (strong,nonatomic) IBOutlet NSArrayController *arrayController;
@property (strong,nonatomic) IBOutlet NSButton *stopBtn;
@property (strong,nonatomic) IBOutlet NSProgressIndicator *activityView;
@property (strong,nonatomic) IBOutlet NSButton *startBtn;
@property (strong,nonatomic) IBOutlet NSButton *signalBtn;
@property (strong,nonatomic) IBOutlet NSComboBox *hostSelector;
@property (strong,nonatomic) IBOutlet NSTableView *clientsTableView;
@property (strong,nonatomic) IBOutlet NSTextField *statusView;
@property (strong,nonatomic) IBOutlet NSTextField *inView;
@property (strong,nonatomic) IBOutlet NSTextField *outView;
@property (strong,nonatomic) IBOutlet NSTextField *portIn;


@end
