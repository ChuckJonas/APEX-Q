//Author: Charlie Jonas
//  Proof of concept for a 'Promise-Like' implementation using Apex Queueables. 
public virtual class Promise implements Queueable {

    //store promise actions to execute.  
    //  If we implement 'Database.AllowCallouts' then use the StackItem to serialize the stack.  
    //  Otherwise just store Promise Actions
    protected List<Object> promiseStack = new List<Object>();
    
    //handlers
    protected Error errorHandler;
    protected Done doneHandler;

    //stores data to pass from one promise to the next
    protected Object heap; 

    //used to determine if we need to enqueue in future context
    private Boolean requiresFuture {
        get {
            if(requiresFuture == null){
                requiresFuture = this instanceOf Database.AllowsCallouts;
            }
            return requiresFuture;
        }
        private set;
    }

    public Promise(){}

    /**
     * Shortcut Constructor to add first action
     * @param  action First action to run
     */
    public Promise(Action action){
        then(action);
    }


    //=== Methods ===
    
    /**
     * Add a new promise action to the execution stack
     * @param  action Action to execute
     * @return        this (for chaining)
     */
    public Promise then(Action action){
        if(requiresFuture){
            promiseStack.add(new StackItem(action));
        }else{
            promiseStack.add(action);
        }
        return this;
    }

    /**
     * Sets the error (Catch) handler.  Can only have 1
     * @param  errorHandler The handler to use
     * @return              this (for chaining)
     */
    public Promise error(Error errorHandler){
        this.errorHandler = errorHandler;
        return this;
    }

    /**
     * Sets the Done (Finally) handler.  Can only have 1
     * @param  doneHandler The handler to use
     * @return             this (for chaining)
     */
    public Promise done(Done doneHandler){
        this.doneHandler = doneHandler;
        return this;
    }

    /**
     * starts the promise execution
     * @param input Object to pass to the first Action
     */
    public void execute(Object input){
        heap = input;
        System.enqueueJob(this);
    }

    /**
     * Runs through the promises execution stack, chaining a new Queuable for each Action
     * @param context System Injected
     */
    public void execute(QueueableContext context) {
        if(Label.Kill_Promise == '1') return;

        Action currentPromise;
        Object resolution;
        try{
            
            //init the next action to run
            Object pop = promiseStack.remove(0);
            if(requiresFuture){
                StackItem si = (StackItem) pop;
                currentPromise = (Action) JSON.deserialize(si.objJSON, Type.forName(si.classType));
            }else{
                currentPromise = (Action) pop;
            }
           
            //resolve action
            resolution = currentPromise.resolve(heap);
            
            //if more actions, re-enqueue
            if(promiseStack.size() > 0){
                if(requiresFuture){
                    //pass everything we need through serialization
                    enqueueJobFuture(
                        getInstanceClassName(this), 
                        JSON.serialize(promiseStack),
                        JSON.serialize(resolution),
                        getInstanceClassName(resolution),
                        JSON.serialize(errorHandler),
                        getInstanceClassName(errorHandler),
                        JSON.serialize(doneHandler),
                        getInstanceClassName(doneHandler)
                    );
                }else{ 
                    //set heap and re-enqueue
                    heap = resolution;
                    System.enqueueJob(this);
                }
                return; 
            }
        }catch(Exception e){
            if(errorHandler != null){
                errorHandler.error(Type.forName(getInstanceClassName(currentPromise)), e);
            }else{
                System.debug('No Error Handler Defined');
                throw e;
            }
        }

        //All actions done, or error. 
        //Execute 'finally' handler
        if(doneHandler != null){
            doneHandler.done(resolution);
        }
    }

    /**
     * Method to enqueue for future execution.  Used for Callout Promise, 
     *   or possibily other extension of promise that levelage callouts
     * @param promiseClassName The name of the Promise Class we are Executing
     * @param promiseStack     Serialized list of StackItem
     * @param heap             Seralized values to pass to next execution
     * @param heapClassName    Heap Object Type
     * @param error            Serialized error handler class
     * @param errorClassName   Error Handler Class Type
     * @param done             Serialized Done handler class
     * @param doneClassName    Done Handler Class Type
     */
    @future(callout=true)
    private static void enqueueJobFuture(String promiseClassName, String promiseStack, 
                                                        String heap, String heapClassName,
                                                        String error, String errorClassName,
                                                        String done, String doneClassName){

        Promise p = (Promise) Type.forName(promiseClassName).newInstance();
        p.promiseStack = (List<StackItem>) JSON.deserialize(promiseStack, StackItem[].class);
        System.debug(error);
        System.debug(errorClassName);
        p.errorHandler = (Error) JSON.deserialize(error, Type.forName(errorClassName));
        p.doneHandler  = (Done) JSON.deserialize(done, Type.forName(doneClassName));

        Type heapType = Type.forName(heapClassName);
        if(heapType == null){ 
            //use generic
            p.heap = JSON.deserializeUntyped(heap);
        }else{
            p.heap = JSON.deserialize(heap, heapType);
        }
        
        //enqueue
        System.enqueueJob(p);
    }   

    //=== Helpers === 
    // NOTE: Does not work with inner classes!
    private static String getInstanceClassName(Object o){
        return String.valueOf(o).split(':')[0];
    }

    //=== Helper Class ===
    public class StackItem{
        public StackItem(Action action){
            classType = getInstanceClassName(action);
            objJSON = JSON.serialize(action);
        }
        
        public String classType {get; private set;}
        public String objJSON  {get; private set;}
    }

    //=== Interfaces ===
    
    public interface Action {
        //Execution action.  Return "response" object if successful.  
        //Otherwise throw exection
        Object resolve(Object input);

    }

    //use as catch blocks
    public interface Error {
        void error(Type t, Exception e);
    }

    //use as finally blocks
    public interface Done{
        void done(Object input);
    }

}