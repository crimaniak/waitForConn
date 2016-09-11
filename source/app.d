import vibe.d;

shared static this()
{
	auto settings = new HTTPServerSettings;
	settings.port = 8081;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	listenHTTP(settings, &hello);

	logInfo("Please open http://127.0.0.1:8081/ in your browser.");
}

void hello(HTTPServerRequest request, HTTPServerResponse response)
{
	import vibe.core.concurrency;
	import std.datetime;
	
	auto mainTask = Task.getThis();
	auto output = response.bodyWriter();
	
	auto running = true;
	scope(exit) running = false;

	// output with flush
	void echo(string message)
	{
		output.write(message);
		output.flush;
	}

	enum Command { Ping, Exit, SilentExit }

	// stop in 10 seconds
	runTask((){
		sleep(10.seconds);
		if(mainTask && mainTask.running())
			mainTask.send(Command.Exit);
	});
	
	// ping browser every second
	runTask((){
		while(mainTask && mainTask.running())
		{
			mainTask.send(Command.Ping);
			sleep(1.seconds);
		}
	});

	// expected: exit main loop if connection is closed from another side
	// in fact: Task terminated with unhandled exception: Acquiring reader of already owned connection.
	runTask((){
		while(!response.waitForConnectionClose() && mainTask.running()){}
		if(mainTask && mainTask.running())
			mainTask.send(Command.SilentExit);
	});

	// run main loop
	bool exit = false;
	while(!exit) receive(
		(Command cmd){
			with(Command) final switch(cmd)
			{
				case Ping: 
					echo("<p>Ping!</p>");
					break;
					
				case Exit:
					echo("<p>stop</p>");
					goto case;
					
				case SilentExit:
					exit = true;
			}
		}
	);
}