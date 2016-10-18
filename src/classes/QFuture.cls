//Author: Charlie Jonas
//Use for promises that require callouts.  Will attempt to serialize data.
//  IMPORTANT: Due to Apex's lack of proper reflection,
//      All Action, Error & Done classes MUST be Top level and completely serializable!
//        Inner classes and non-serializable properties will cause failure!
public class QFuture extends QBase implements Queueable, Database.AllowsCallouts {
    //store promise actions to execute.
    protected List<TypedSerializable> promiseStack = new List<TypedSerializable>();

    public QFuture(){}

    public QFuture(Q.Action action){
        then(action);
    }

    /**
     * Add a new promise action to the execution stack
     * @param  action Action to execute
     * @return        this (for chaining)
     */
    public override QBase then(Q.Action action){
        promiseStack.add(new TypedSerializable(action));
        return this;
    }

    /**
     * Runs through the promises execution stack, chaining a new Queuable for each Action
     * @param context System Injected
     */
    public void execute(QueueableContext context) {

        Q.Action currentPromise;
        TypedSerializable resolution;
        try{
            TypedSerializable si = (TypedSerializable) promiseStack.remove(0);
            currentPromise = (Q.Action) JSON.deserialize(si.objJSON, Type.forName(si.classType));

            resolution = (TypedSerializable) currentPromise.resolve(heap);

            //continue execution
            if(promiseStack.size() > 0){
                enqueueJobFuture(
                    getInstanceClassName(this),
                    JSON.serialize(promiseStack),
                    resolution.objJSON,
                    resolution.classType,
                    errorHandler==null?null:JSON.serialize(errorHandler),
                    getInstanceClassName(errorHandler),
                    doneHandler==null?null:JSON.serialize(doneHandler),
                    getInstanceClassName(doneHandler)
                );
                return;
            }
        }catch(Exception e){
            if(errorHandler != null){
                resolution = (TypedSerializable) errorHandler.error(e);
            }else{
                System.debug(e.getMessage());
                System.debug(e.getStackTraceString());
                throw e;
            }
        }

        //All actions done, or error.
        //Execute 'finally' method
        if(doneHandler != null){
            doneHandler.done(JSON.deserialize(resolution.objJSON, Type.forName(resolution.classType)));
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
    public static void enqueueJobFuture(String promiseClassName, String promiseStack,
                                                        String heap, String heapClassName,
                                                        String error, String errorClassName,
                                                        String done, String doneClassName){

        QFuture p = new QFuture();
        p.promiseStack = (List<TypedSerializable>) JSON.deserialize(promiseStack, TypedSerializable[].class);

        if(error != null && errorClassName != null){
            p.error((Q.Error) JSON.deserialize(error, Type.forName(errorClassName)));
        }

        if(done != null && doneClassName != null){
            p.done((Q.Done) JSON.deserialize(done, Type.forName(doneClassName)));
        }

        if(heap != null && heapClassName != null){
            Type heapType = Type.forName(heapClassName);
            if(heapType == null){ //use generic class
                p.heap = JSON.deserializeUntyped(heap);
            }else{
                p.heap = JSON.deserialize(heap, heapType);
            }
        }

        //enqueue
        System.enqueueJob(p);
    }

    //=== Helpers ===
    private static String getInstanceClassName(Object o){
        if(o == null) return null;
        return String.valueOf(o).split(':')[0];
    }

    //=== Helper Classes ===
    public class TypedSerializable{
        public TypedSerializable(Q.Action action){
            classType = getInstanceClassName(action);
            objJSON = JSON.serialize(action);
        }

        public TypedSerializable(Object obj, Type t){
            this.objJSON = JSON.serialize(obj);
            this.classType = t.getName();
        }

        public String classType {get; private set;}
        public String objJSON  {get; private set;}
    }

}