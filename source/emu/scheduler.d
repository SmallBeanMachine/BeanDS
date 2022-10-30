module emu.scheduler;

import util;

struct Event {
    void delegate() callback;
    ulong           timestamp;
	EventID         id;
    bool            completed;
}

alias EventID = ulong;

__gshared Scheduler scheduler;
final class Scheduler {
    enum TOTAL_NUMBER_OF_EVENTS = 0x100;

    Event*[TOTAL_NUMBER_OF_EVENTS] events;
    
    int     events_in_queue;
    EventID id_counter;
    ulong   current_timestamp;
    bool    event_in_progress;

    this() {
        for (int i = 0; i < TOTAL_NUMBER_OF_EVENTS; i++) {
        	events[i] = new Event(null, 0, 0, false);
        }
        
        events_in_queue   = 0;
        id_counter        = 0;
        current_timestamp = 0;
        event_in_progress = false;

        scheduler = this;
    }

    ulong add_event_relative_to_clock(void delegate() callback, int delta_cycles) {
        return add_event(callback, current_timestamp + delta_cycles);
    }

    ulong add_event_relative_to_self(void delegate() callback, int delta_cycles) {
        return add_event(callback, events[0].timestamp + delta_cycles);
    }

    private ulong add_event(void delegate() callback, ulong timestamp) {
        if (events_in_queue == TOTAL_NUMBER_OF_EVENTS) {
            error_scheduler("Error when adding event: Scheduler is full.");
        }

        int insert_at;

        for (; insert_at < events_in_queue; insert_at++) {
            if (timestamp < events[insert_at].timestamp) {
            	break;
            }
        }
        
        for (int i = events_in_queue; i > insert_at; i--) {
            *events[i] = *events[i - 1];
        }
        
        id_counter++;
        events_in_queue++;
        *events[insert_at] = Event(callback, timestamp, id_counter);
        
        return id_counter;
    }

    void remove_event(ulong event_id) {
        if (events_in_queue == TOTAL_NUMBER_OF_EVENTS) {
            error_scheduler("Error when removing event: Scheduler is full.");
        }

        int remove_at = -1;
        for (int i = 0; i < events_in_queue; i++) {
            if (events[i].id == event_id) {
            	remove_at = i;
                break;
            }
        }

        if (remove_at == -1) return;
        
        for (int i = remove_at; i < events_in_queue; i++) {
            *events[i] = *events[i + 1];
        }
        
        events_in_queue--;
    }

    pragma(inline, true) void tick(ulong num_cycles) {
        current_timestamp += num_cycles;
    }

    pragma(inline, true) void tick_to_next_event() {
        current_timestamp = events[0].timestamp;
    }

    pragma(inline, true) void process_events() {
        while (current_timestamp >= events[0].timestamp) process_event();
    }

    pragma(inline, true) ulong get_current_time() {
        return current_timestamp;
    }

    pragma(inline, true) ulong get_current_time_relative_to_cpu() {
        return current_timestamp;
    }

    pragma(inline, true) ulong get_current_time_relative_to_self() {
        return events[0].timestamp;
    }

    pragma(inline, true) void process_event() {
        if (event_in_progress) return;

        event_in_progress = true;
        events[0].callback();

        for (int i = 0; i < events_in_queue; i++) {
            *events[i] = *events[i + 1];
        }
        
        events_in_queue--;
        event_in_progress = false;
    }
}