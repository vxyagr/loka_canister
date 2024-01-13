import Time "mo:base/Time";
//import Principal "motoko/util/Principal";


module {

    public type Token = Principal;

    public type OrderId = Nat32;

    public type TransactionHistory = {
        id: Nat;
        //caller: Text;
        time : Int;
        action: Text;
        amount: Text;
        txid : Text;
        currency : Text;
    };

    public type WalletAddress = {
        name : Text;
        address : Text;
        currency : Text;
    };

    public type BankAddress = {
        name : Text;
        accountNumber : Text;
        bankName : Text;
        jwalletId : Text;
    };

    public type Duration = {#seconds : Nat; #nanoseconds : Nat};

    
    
    public type MinerStatus = {
        id : Nat;
        var verified : Bool;
        var balance : Nat;
        var totalWithdrawn : Nat;
        var walletAddress : [WalletAddress];
        var bankAddress : [BankAddress];
        var transactions : [TransactionHistory];
    };
    
    public type Miner = {
        id : Nat;
        walletAddress : Principal;
        var username : Text;
        hashrate : Nat;
     };

    

     /*public type MinerReward = {
        id : Nat;
        var available : Float;
        var claimed : Float;
     };*/

    public type MinerData = {
        id : Nat;
        walletAddress : Principal;
        walletAddressText : Text;
        username : Text;
        hashrate : Nat;
        verified : Bool;
        balance : Nat;
        totalWithdrawn : Nat;
     
        savedWalletAddress : [WalletAddress];
        bankAddress : [BankAddress];
     };

     public type Timestamp = Nat64;
  
  // First, define the Type that describes the Request arguments for an HTTPS outcall.

    public type HttpRequestArgs = {
        url : Text;
        max_response_bytes : ?Nat64;
        headers : [HttpHeader];
        body : ?[Nat8];
        method : HttpMethod;
        transform : ?TransformRawResponseFunction;
    };

    public type TransferRes = {
        #success : Nat;
        #error : Text;
    };

    public type HttpHeader = {
        name : Text;
        value : Text;
    };

    public type HttpMethod = {
        #get;
        #post;
        #head;
    };

    public type HttpResponsePayload = {
        status : Nat;
        headers : [HttpHeader];
        body : [Nat8];
    };

    // HTTPS outcalls have an optional "transform" key. These two types help describe it.
    // The transform function can transform the body in any way, add or remove headers, or modify headers.
    // This Type defines a function called 'TransformRawResponse', which is used above.
    
    public type TransformRawResponseFunction = {
        function : shared query TransformArgs -> async HttpResponsePayload;
        context : Blob;
    };

    // This Type defines the arguments the transform function needs.
    public type TransformArgs = {
        response : HttpResponsePayload;
        context : Blob;
    };

    public type CanisterHttpResponsePayload = {
        status : Nat;
        headers : [HttpHeader];
        body : [Nat8];
    };

    public type TransformContext = {
        function : shared query TransformArgs -> async HttpResponsePayload;
        context : Blob;
    };


    // Lastly, declare the IC management canister which you use to make the HTTPS outcall.
    public type IC = actor {
        http_request : HttpRequestArgs -> async HttpResponsePayload;
    };

    
    
};
