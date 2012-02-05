namespace Musicbrainz {

    public interface Task : Object {
        public abstract void execute ();
    }

    internal class TaskExecuter {
        
        // TODO: provide those values to the constructor 
        //       allow to change them runtime
        static const ulong CONSEC_TIME_INTERVAL = 1000 * 1000 * 1; // 1 second
        static const ulong TIME_INTERVAL = 10 * CONSEC_TIME_INTERVAL;
        static const ulong TASKS_ALLOWED = 10;

        Gee.Deque <Task> tasks = new Gee.LinkedList <Task> ();
        Gee.Deque <DateTime> execute_times = new Gee.LinkedList <DateTime> ();

        ThreadFunc<void *> loop;
        unowned Thread<void *> thread;

        Cond tasks_cond = new Cond ();
        Mutex tasks_mutex = new Mutex ();
      
        Cond executed_cond = new Cond ();
        Mutex executed_mutex = new Mutex ();

        Task? last_executed_task = null;

        void execute_task () {
            var task = tasks.poll_head ();
            
            task.execute (); 
            last_executed_task = task;

            executed_mutex.lock ();
            executed_cond.signal ();
            executed_mutex.unlock ();

            execute_times.offer_tail (new DateTime.now_local ());

        }

        internal TaskExecuter () {
             loop = () => {
                while (true) {
                    if (tasks.is_empty) {
                        tasks_mutex.lock ();
                        while (tasks.is_empty)
                            tasks_cond.wait (tasks_mutex);
                        tasks_mutex.unlock ();
                    }

                    if (execute_times.is_empty) {
                        execute_task ();
                    } else {

                        var now = new DateTime.now_local ();
                        var last_request_time = execute_times.peek_tail ();
                        ulong delta = (ulong)now.difference (last_request_time);

                        if (delta < CONSEC_TIME_INTERVAL) {
                            Thread.usleep (CONSEC_TIME_INTERVAL - delta);
                        }

                        execute_task ();
                        execute_times.poll_head ();
                        // TODO: some burst strategy based on 
                        //       saving last 10 execution times instead of 1
                    }
                }
             };
             try {
                 thread = Thread.create<void *> (loop, false);
             } catch (ThreadError e) {
                 stderr.printf ("Error during initialization: %s\n", e.message);
                 Posix.exit (1);
             }
        }

        public void add_task (Task task) {
            tasks_mutex.lock();
            tasks.offer_tail (task);
            tasks_cond.signal ();
            tasks_mutex.unlock();
        }

        public void add_task_and_wait (Task task) {
            executed_mutex.lock ();
            add_task (task);
            while (last_executed_task != task)
                executed_cond.wait (executed_mutex);
            executed_mutex.unlock ();
        }

    }

}
