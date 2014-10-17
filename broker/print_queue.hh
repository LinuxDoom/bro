#ifndef BROKER_PRINT_QUEUE_HH
#define BROKER_PRINT_QUEUE_HH

#include <broker/endpoint.hh>
#include <broker/print_msg.hh>
#include <string>
#include <memory>
#include <deque>

namespace broker {

class print_queue {
public:

	/**
	 * Create an uninitialized print queue.  It will never contain any messages.
	 */
	print_queue();

	/**
	  * Destruct print queue.
	  */
	~print_queue();

	/**
	 * Copying a print queue is disallowed.
	 */
	print_queue(const print_queue& other) = delete;

	/**
	 * Steal a print queue.
	 */
	print_queue(print_queue&& other);

	/**
	 * Copying a print queue is disallowed.
	 */
	print_queue& operator=(const print_queue& other) = delete;

	/**
	 * Replace print queue by stealing another.
	 */
	print_queue& operator=(print_queue&& other);

	/**
	 * Create a print queue that will receive print messages directly from an
	 * endpoint or via one if its peers.
	 * @param topic_name only print messages that match this string are
	 *                   received.
	 * @param e a local endpoint.
	 */
	print_queue(std::string topic_name, const endpoint& e);

	/**
	 * @return a file descriptor that is ready for reading when the queue is
	 *         non-empty, suitable for use with poll, select, etc.
	 */
	int fd() const;

	/**
	 * @return Any print messages that are available at the time of the call.
	 */
	std::deque<print_msg> want_pop() const;

	/**
	 * @return At least one print message.  The call blocks if it must.
	 */
	std::deque<print_msg> need_pop() const;

	/**
	 * @return the topic name associated with the queue.
	 */
	const std::string& topic_name() const;

private:

	class impl;
	std::unique_ptr<impl> pimpl;
};

} // namespace broker

#endif // BROKER_PRINT_QUEUE_HH
