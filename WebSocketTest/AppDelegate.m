//
//  AppDelegate.m
//  WebSocketTest
//
//  Created by A. Vatsaev on 09/12/2013.
//  Copyright (c) 2013 Vatsaev Aslan. All rights reserved.
//

#import "AppDelegate.h"


#define WELCOME_MSG  0
#define ECHO_MSG     1
#define WARNING_MSG  2

#define READ_TIMEOUT 60.0
#define READ_TIMEOUT_EXTENSION 55.0

#define FORMAT(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]
#define APPEND(string1, string2) [string1 stringByAppendingString: string2]
#define EQUAL(string1, string2) [string1 isEqualToString:string2]

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    
    // Setup an array to store all accepted client connections
    connectedSockets = [[NSMutableArray alloc] initWithCapacity:1];
    connectedClients = [[NSMutableArray alloc] initWithCapacity:1];
    //[connectedClients addObject:@{@"ip":@"dsfsfsfs",@"port":@"80"}];
    
    
    self.arrayController  = [NSArrayController alloc].init;
    
    [self.arrayController addObject:@{@"ip":@"ip", @"port":@"port"}];
    
    self.clientsTableView.delegate =self;
    
    
    
    self.status =0;
    [self.stopBtn setEnabled:NO];
    [self.signalBtn setEnabled:NO];

    [self.hostSelector addItemsWithObjectValues:[[NSHost currentHost] addresses]];

    [self.hostSelector selectItemAtIndex:1];

    

}



- (IBAction)startServ:(id)sender {
    [self networkIsActive:YES];
    NSLog(@"start...");
    if([[self.portIn stringValue] isEqual:@""]){
        [self appendOut:@"set port."];
    }else{
        
        if (port < 1025 || port > 65535)
		{
			[self.portIn setStringValue:@"32079"];
			port = 32079;
            
		}else if(port==0){
            [self.portIn setStringValue:@"32079"];
            port = 32079;
        }else{
            port = [self.portIn intValue];
        }

        NSError *error = nil;
		if(![listenSocket acceptOnInterface: [self.hostSelector objectValueOfSelectedItem] port: port error: &error]){
            
			[self appendOut:FORMAT(@"Error starting server: %@", error)];
            self.status=0;
            [self updateStatus];
			return;
		}
		
		//[self appendOut:FORMAT(@"Echo server started on port %hu", [listenSocket localPort])];
        
        [self appendOut:FORMAT(@"Server started on %@:%d ", [listenSocket localHost],[listenSocket localPort] )];
        
        self.status=1;
        [self updateStatus];
    }
    
    [self networkIsActive:NO];
    
}

- (IBAction)stopServ:(id)sender {
    [self networkIsActive:YES];
    NSLog(@"stop...");
    
    [listenSocket disconnect];
    
    // Stop any client connections
    @synchronized(connectedSockets)
    {
        NSUInteger i;
        for (i = 0; i < [connectedSockets count]; i++)
        {
            [[connectedSockets objectAtIndex:i] disconnect];
        }
    }
    
    self.status =0;
    [self updateStatus];
    [self networkIsActive:NO];
}





//new connection established
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    
    
    [self networkIsActive:YES];
    
    
	@synchronized(connectedSockets){
        
		[connectedSockets addObject:newSocket];
	}
	
	NSString *host = [newSocket connectedHost];
	UInt16 _port = [newSocket connectedPort];
    
    [self.arrayController addObject:@{@"ip":[newSocket connectedHost], @"port": FORMAT(@"%ud",_port)}];
     NSLog(@"--------- %@",self.arrayController);
    [self.clientsTableView reloadData];
    
	
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
            
			[self appendOut:FORMAT(@"Accepted client %@:%hu", host, _port)];
            
		}
	});
	
    NSString *welcomeMsg = @"Welcome to the AZR Echo Server\r\n";
    NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
	
	[newSocket writeData:welcomeData withTimeout:-1 tag:WELCOME_MSG];
	
	[newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:READ_TIMEOUT tag:0];
    [self networkIsActive:NO];
}








//Client disconnected
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    [self networkIsActive:YES];
	if (sock != listenSocket)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			@autoreleasepool {
                
				[self appendOut:FORMAT(@"Client %lu disconnected", (unsigned long)[connectedSockets indexOfObject:sock])];
                [connectedSockets removeObject:sock];
			}
		});
		
		@synchronized(connectedSockets)
		{
			
		}
	}
    [self networkIsActive:NO];
}







// client did write data
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    [self networkIsActive:YES];
	// This method is executed on the socketQueue (not the main thread)
	
	if (tag == ECHO_MSG)
	{
		[sock readDataToData:[GCDAsyncSocket ZeroData] withTimeout:READ_TIMEOUT tag:ECHO_MSG];
	}
    [self networkIsActive:NO];
}






//????

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	// This method is executed on the socketQueue (not the main thread)
	[self networkIsActive:YES];
	dispatch_async(dispatch_get_main_queue(), ^{
		@autoreleasepool {
            
			NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
			NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
			if (msg)
			{
				[self appendIn:msg];
			}
			else
			{
				[self appendOut:@"Error converting received data into UTF-8 String"];
			}
            
		}
	});
	
	// Echo message back to client
	[sock writeData:data withTimeout:-1 tag:30];
    [self networkIsActive:NO];
}













- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
	if (elapsed <= READ_TIMEOUT)
	{
		NSString *warningMsg = @"TIMEOUT: connection is about to be closed\r\n";
		NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
		
		[sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];
		
		return READ_TIMEOUT_EXTENSION;
	}
	
	return 0.0;
}









-(void)appendIn: (NSString*)incoming{
    [self.inView setStringValue:[NSString stringWithFormat:@"%@\n%@",incoming,self.inView.stringValue]];
    
}

-(void)appendOut: (NSString*)outgoing{
    [self.outView setStringValue:[NSString stringWithFormat:@"%@\n%@",outgoing,self.outView.stringValue]];
    
}





- (IBAction)pingClient:(id)sender {
    [self networkIsActive:YES];
    NSString *warningMsg = @"SERVER: Ping!!!\r\n";
    NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
    @synchronized(connectedSockets)
    {
        NSUInteger i;
        for (i = 0; i < [connectedSockets count]; i++)
        {
            [[connectedSockets objectAtIndex:i] writeData:warningData withTimeout:-1 tag:ECHO_MSG];
        }
    }
    [self networkIsActive:NO];
    
}





-(void)updateStatus{
    switch (self.status) {
        case 0:
            NSLog(@"status off");
            [self.stopBtn setEnabled:NO];
            [self.signalBtn setEnabled:NO];
            [self.startBtn setEnabled:YES];
            [self.portIn setEnabled: YES];
            [self.hostSelector setEnabled: YES];
            [self.statusView setStringValue:@"OFF"];
            self.statusView.textColor = [NSColor redColor];
            break;

        case 1:
            NSLog(@"status on");

            [self.stopBtn setEnabled:YES];
            [self.signalBtn setEnabled:YES];
            [self.startBtn setEnabled:NO];
            [self.portIn setEnabled: NO];
            [self.hostSelector setEnabled: NO];
            [self.statusView setStringValue:@"ON"];
            self.statusView.textColor = [NSColor colorWithCalibratedRed:0.000 green:0.785 blue:0.008 alpha:1.000];

            break;

        case -1:
            NSLog(@"error");
            break;


        default:
            break;
    }
}





- (IBAction)clearIn:(id)sender {
    [self.inView setStringValue:@""];
}

- (IBAction)clearOut:(id)sender {
    [self.outView setStringValue:@""];
}

-(void)networkIsActive: (BOOL) active{
    
    if(active){
        [self.activityView startAnimation:nil];
    }else{
        [self.activityView stopAnimation:nil];
    }
    
}









- (int)numberOfRowsInTableView:(NSTableView *)pTableViewObj {
    return 20;
}






@end
