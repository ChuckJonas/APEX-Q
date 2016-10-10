public abstract class BasePromise {

    //handlers
    public Promise.Error errorHandler;
    public Promise.Done doneHandler;

    //stores data to pass from one promise to the next
    public Object heap; 

    public abstract BasePromise then(Promise.Action action);

    /**
     * Sets the error (Catch) handler.  Can only have 1
     * @param  errorHandler The handler to use
     * @return              this (for chaining)
     */
    public BasePromise error(Promise.Error errorHandler){
        this.errorHandler = errorHandler;
        return this;
    }

    /**
     * Sets the Done (Finally) handler.  Can only have 1
     * @param  doneHandler The handler to use
     * @return             this (for chaining)
     */
    public BasePromise done(Promise.Done doneHandler){
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
}