# @TEST-SERIALIZE: brokercomm
# @TEST-REQUIRES: grep -q ENABLE_BROKER $BUILD/CMakeCache.txt

# @TEST-EXEC: btest-bg-run clone "bro -b ../clone.bro broker_port=$BROKER_PORT >clone.out"
# @TEST-EXEC: btest-bg-run master "bro -b ../master.bro broker_port=$BROKER_PORT >master.out"

# @TEST-EXEC: btest-bg-wait 60
# @TEST-EXEC: TEST_DIFF_CANONIFIER=$SCRIPTS/diff-sort btest-diff clone/clone.out
# @TEST-EXEC: btest-diff master/master.out

@TEST-START-FILE clone.bro

const broker_port: port &redef;
redef exit_only_after_terminate = T;

global h: opaque of Broker::Handle;
global expected_key_count = 4;
global key_count = 0;

global query_timeout = 30sec;

function do_lookup(key: string)
	{
	when ( local res = Broker::lookup(h, Broker::data(key)) )
		{
		++key_count;
		print "lookup", key, res;

		if ( key_count == expected_key_count )
			terminate();
		}
	timeout query_timeout
		{
		print "clone lookup query timeout";
		terminate();
		}
	}

event ready()
	{
	h = Broker::create_clone("mystore");

	when ( local res = Broker::keys(h) )
		{
		print "clone keys", res;
		do_lookup(Broker::refine_to_string(Broker::vector_lookup(res$result, 0)));
		do_lookup(Broker::refine_to_string(Broker::vector_lookup(res$result, 1)));
		do_lookup(Broker::refine_to_string(Broker::vector_lookup(res$result, 2)));
		do_lookup(Broker::refine_to_string(Broker::vector_lookup(res$result, 3)));
		}
	timeout query_timeout
		{
		print "clone keys query timeout";
		terminate();
		}
	}

event bro_init()
	{
	Broker::enable();
	Broker::subscribe_to_events("bro/event/ready");
	Broker::listen(broker_port, "127.0.0.1");
	}

@TEST-END-FILE

@TEST-START-FILE master.bro

global query_timeout = 15sec;

const broker_port: port &redef;
redef exit_only_after_terminate = T;

global h: opaque of Broker::Handle;

function dv(d: Broker::Data): Broker::DataVector
	{
	local rval: Broker::DataVector;
	rval[0] = d;
	return rval;
	}

global ready: event();

event Broker::outgoing_connection_broken(peer_address: string,
                                       peer_port: port)
	{
	terminate();
	}

event Broker::outgoing_connection_established(peer_address: string,
                                            peer_port: port,
                                            peer_name: string)
	{
	local myset: set[string] = {"a", "b", "c"};
	local myvec: vector of string = {"alpha", "beta", "gamma"};
	h = Broker::create_master("mystore");
	Broker::insert(h, Broker::data("one"), Broker::data(110));
	Broker::insert(h, Broker::data("two"), Broker::data(223));
	Broker::insert(h, Broker::data("myset"), Broker::data(myset));
	Broker::insert(h, Broker::data("myvec"), Broker::data(myvec));
	Broker::increment(h, Broker::data("one"));
	Broker::decrement(h, Broker::data("two"));
	Broker::add_to_set(h, Broker::data("myset"), Broker::data("d"));
	Broker::remove_from_set(h, Broker::data("myset"), Broker::data("b"));
	Broker::push_left(h, Broker::data("myvec"), dv(Broker::data("delta")));
	Broker::push_right(h, Broker::data("myvec"), dv(Broker::data("omega")));

	when ( local res = Broker::size(h) )
		{ event ready(); }
	timeout query_timeout
		{
		print "master size query timeout";
		terminate();
		}
	}

event bro_init()
	{
	Broker::enable();
	Broker::auto_event("bro/event/ready", ready);
	Broker::connect("127.0.0.1", broker_port, 1secs);
	}

@TEST-END-FILE
