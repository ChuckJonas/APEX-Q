//Use for promises that require callouts.  Will attempt to serialize data.  
//  IMPORTANT: Due to Apex's lack of proper reflection, 
//      All Action, Error & Done classes MUST be Top level and completely serializable! 
//        Inner classes and non-serializable properties will cause failure!
public class CalloutPromise extends Promise implements Database.AllowsCallouts {
    public CalloutPromise(){}
    public CalloutPromise(Action action){
        super(action);
    }
}