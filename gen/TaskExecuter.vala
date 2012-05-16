/* 
   
  This file is part of libmusicbrainz-vala.
  Copyright (C) 2012 Artem Tarasov
  
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

namespace Musicbrainz {

    public interface Task : Object {
        public abstract async void execute ();
    }

    internal class TaskExecuter {
        
        public enum ExecutingMode {
            NORMAL,
            BURST
        }

        class InternalTask : Object, Task {
            SourceFunc notify_caller;
            public ExecutingMode mode;
            Task task;
            public InternalTask (Task task, owned SourceFunc callback, ExecutingMode mode) {
                notify_caller = (owned) callback;
                this.task = task;
                this.mode = mode;
            }
            public async void execute () {
                yield task.execute ();

                // now we notify the caller that the task was executed
                Idle.add ((owned) notify_caller);
            }
        }

        uint tasks_allowed;
        uint time_interval;
        public uint consecutive_time_interval;

        ExecutingMode mode = ExecutingMode.NORMAL;
    
        uint? tasks_to_burst = null;

        // tasks to be run
        Gee.Queue <InternalTask> tasks = new Gee.LinkedList <InternalTask> ();

        // times of last task runs
        Gee.Deque <DateTime> execute_times = new Gee.LinkedList <DateTime> ();

        bool execute_times_deque_is_full {
            get { return execute_times.size == tasks_allowed - 1; }
        }

        ulong tasks_executed = 0;

        async void execute_next_task () {
            var task = tasks.poll ();
            
            // update the deque
            if (execute_times_deque_is_full) 
                execute_times.poll_head ();
           
            execute_times.offer_tail (new DateTime.now_local ());

            ++tasks_executed;
            yield task.execute (); 

        }

        public TaskExecuter (uint time_interval, uint tasks_allowed) {
            assert (tasks_allowed > 0);
            this.time_interval = time_interval;
            this.tasks_allowed = tasks_allowed;
            this.consecutive_time_interval = time_interval / tasks_allowed;

            loop ();
        }

        SourceFunc? add_task_callback = null;
        
        async void loop () {
            // the following invariants hold:
            //  1) in both BURST and NORMAL modes,
            //     the number of tasks executed per any time_interval
            //     does not exceed tasks_allowed
            //  2) in NORMAL mode, the time interval between
            //     consecutive task executions is 
            //     >= time_interval / tasks_allowed. 

            while (true) {

                if (tasks.is_empty) {
                    set_add_task_callback (loop.callback);
                    yield; 
                }
                
                // now the tasks queue is non empty

                if (execute_times.is_empty) {
                    yield execute_next_task ();
                } else {

                    // wait until it's allowed to execute the task  
                    uint timeout = 0;

                    var now = new DateTime.now_local ();
                   
                    var next_task = tasks.peek ();

                    if (next_task.mode == ExecutingMode.NORMAL && !execute_times.is_empty) {
                        var last_request_time = execute_times.peek_tail ();
                        uint delta = (uint)now.difference (last_request_time);
                    
                        if (delta < consecutive_time_interval) {
                            var tmp = consecutive_time_interval - delta;
                            if (tmp > timeout) timeout = tmp;
                        }
                    }

                    if (tasks_executed >= tasks_allowed) {
                        var first_request_time = execute_times.peek_head ();
                        uint delta = (uint)now.difference (first_request_time);
                    
                        if (delta < time_interval) {
                            var tmp = time_interval - delta;
                            if (tmp > timeout) timeout = tmp;
                        }
                    }

                    if (timeout > 0) {
                        timeout /= 1000; // microseconds ->  milliseconds
                        Timeout.add (timeout, loop.callback);
                        yield;
                    }

                    yield execute_next_task ();
                }
            }
        }

        void set_add_task_callback (owned SourceFunc callback) {
            add_task_callback = (owned) callback;
        }

        public void add_task (Task task, owned SourceFunc callback) {
            lock (tasks) {
                tasks.offer (new InternalTask (task, (owned) callback, mode));
                if (tasks.size == 1 && add_task_callback != null) {
                    // add_task_callback != null only while the queue is empty
                    Idle.add ((owned) add_task_callback);
                }

                if (tasks_to_burst != null) {
                    if (--tasks_to_burst == 0) {
                        mode = ExecutingMode.NORMAL;
                        tasks_to_burst = null;
                    }
                }
            }
        }

        public async void execute_task (Task task) {
            add_task (task, execute_task.callback);
            yield;
        }

        public void enter_burst_mode (uint num_of_tasks) {
            mode = ExecutingMode.BURST;
            if (tasks_to_burst == null) {
                tasks_to_burst = num_of_tasks;
            } else {
                tasks_to_burst += num_of_tasks;
            }
        }
       
    }

}
