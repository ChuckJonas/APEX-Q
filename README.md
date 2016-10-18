# apex-promises
A promise library for Salesforce.

## Why?!
This was inspired by a 2016 Dreamforce Sessions [Apex Promises](https://success.salesforce.com/Sessions?eventId=a1Q3000000qQOd9EAG#/session/a2q3A000000LBdnQAG) by [Kevin Poorman](https://github.com/codefriar).  I thought it would be fun to take it a step further and see how close you could get to a reusable "Promise" implementation. 

## Usage:

### Without Callouts
For Promises without Callouts, Inner-Classes and Non-Serializable types can be used.  The Promise Library will chain these without using the future method. Below is a trivial example Encypts and Base64 encodes an Account Number field:  
``` java
public class EncryptionPromise{

    public EncryptionPromise(Account acc){
        Blob exampleIv = Blob.valueOf('Example of IV123');
        Blob key = Crypto.generateAesKey(128);

        new Promise(new EncryptionAction(exampleIv, key))
        .then(new Base64EncodingAction())
        .error(new ErrorHandler(acc))
        .done(new DoneHandler(acc))
        .execute(Blob.valueOf(acc.AccountNumber));
    }

    //=== ACTION Handlers ===
    private class EncryptionAction implements Promise.Action{
        private Blob vector;
        private Blob key;
        public EncryptionAction(Blob vector, Blob key){
            this.vector = vector;
            this.key = key;
        }

        public Object resolve(Object input){
            Blob inputBlob = (Blob) input;
            return Crypto.encrypt('AES128', key, vector, inputBlob);
        }
    }

    private class Base64EncodingAction implements Promise.Action {
        public Object resolve(Object input){
            Blob inputBlob = (Blob) input;
            return EncodingUtil.base64Encode(inputBlob);
        }
    }


    //=== Done Handler ===
    private class DoneHandler implements Promise.Done{
        private Account acc;
        public DoneHandler(Account acc){
            this.acc = acc;
        }

        public void done(Object input){
            if(input != null){
                acc.AccountNumber = (String) input;
                System.debug(input);
                update acc;
            }
        }
    }

    //=== DONE Handler ===
    private class ErrorHandler implements Promise.Error{
        private Account acc;
        public ErrorHandler(Account acc){
            this.acc = acc;
        }

        //failed! set account number to null
        public void error(Exception e){
            acc.AccountNumber = null;
            System.debug(e);
            update acc;
        }
    }
}
```

**Note:**
* The return object of each Resolve function is passed into the next
* The Done handler will be called even if there is an error

### With Callouts
The most common use case for a pattern like this would probably be to chain multiple Callout actions.  Unforuntely, due to the lack of proper reflection in Salesforce, the implementation here is less than ideal and rules must be followed:

1. All interfaced Promise implementations (Action, Error, Done) MUST be Top Level classes.  Using Inner Classes will cause failures.
2. All implemented classes MUST be JSON serializable.  Non-Serailizable types will cause a failure!
3. Resolve MUST return a `CalloutPromise.TypedSerializable`

To Specify a Promise with callouts, just use `CalloutPromise` in place of `Promise`:

``` java
public class EncryptionPromise{

    //ALL Promise Implementation Classes defined at top level!
    public EncryptionPromise(Account acc){
        Blob exampleIv = Blob.valueOf('abc');
        Blob key = Crypto.generateAesKey(128);

        new CalloutPromise(new EncryptionAction(exampleIv, key))
        .then(new Base64EncodingAction())
        .error(new ErrorHandler(acc))
        .done(new DoneHandler(acc))
        .execute(Blob.valueOf(acc.AccountNumber));
    }
}

public with sharing class EncryptionAction implements Promise.Action{
    private Blob vector;
    private Blob key;
    public EncryptionAction(Blob vector, Blob key){
        this.vector = vector;
        this.key = key;
    }

    public CalloutPromise.TypedSerializable resolve(Object input){
        Blob inputBlob = (Blob) input;
        return new CalloutPromise.TypedSerializable(Crypto.encrypt('AES128', key, vector, inputBlob), 
                                                    Blob.class);
    }
}
```

## Disclaimer
I have not (and maybe would not) use this in an actual implementation.  Has not been throughly tested.

## LICENSE
The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
