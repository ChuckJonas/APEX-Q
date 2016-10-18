//Author: Charlie Jonas
//  Runs a "Syncronous" (not really, still runs in multiple batches) Q process
public virtual class Q extends QBase implements Queueable {

    //store promise actions to execute.
    //  If we implement 'Database.AllowCallouts' then use the StackItem to serialize the stack.
    //  Otherwise just store Promise Actions
    protected List<Action> promiseStack = new List<Action>();

    public Q(){}

    public Q (Action action){
        then(action);
    }

    //=== Methods ===

    /**
     * Add a new promise action to the execution stack
     * @param  action Action to execute
     * @return        this (for chaining)
     */
    public override QBase then(Action action){
        promiseStack.add(action);
        return this;
    }

    /**
     * Runs through the promises execution stack, chaining a new Queuable for each Action
     * @param context System Injected
     */
    public void execute(QueueableContext context) {

        Action currentPromise;
        Object resolution;
        try{

            currentPromise = promiseStack.remove(0);
            heap = currentPromise.resolve(heap);

            //continue execution
            if(promiseStack.size() > 0){
                System.enqueueJob(this);
                return;
            }
        }catch(Exception e){
            if(errorHandler != null){
                heap = errorHandler.error(e);
            }else{
                System.debug(e.getMessage());
                System.debug(e.getStackTraceString());
                throw e;
            }
        }

        //All actions done, or error.
        //Execute 'finally' method
        if(doneHandler != null){
            doneHandler.done(heap);
        }
    }

    //=== Interfaces ===
    public interface Action {
        //Execution action.  Return "Response" object if successful.
        //Otherwise throw exection
        Object resolve(Object input);
    }

    //use as catch blocks
    public interface Error {
        Object error(Exception e);
    }

    //use as finally blocks
    public interface Done{
        void done(Object input);
    }

}