//Author: Charlie Jonas
// Base Class for Apex "Q"
public abstract class QBase {

    //handlers
    protected Q.Error errorHandler;
    protected Q.Done doneHandler;

    //stores data to pass from one promise to the next
    public Object heap;

    public abstract QBase then(Q.Action action);

    /**
     * Sets the error (Catch) handler.  Can only have 1
     * @param  errorHandler The handler to use
     * @return              this (for chaining)
     */
    public QBase error(Q.Error errorHandler){
        this.errorHandler = errorHandler;
        return this;
    }

    /**
     * Sets the Done (Finally) handler.  Can only have 1
     * @param  doneHandler The handler to use
     * @return             this (for chaining)
     */
    public QBase done(Q.Done doneHandler){
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