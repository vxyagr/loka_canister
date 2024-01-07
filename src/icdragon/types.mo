import Time "mo:base/Time";
//import Principal "motoko/util/Principal";


module {

    public type Token = Principal;

    public type OrderId = Nat32;


    

     public type Bet = {
        id: Nat;
        game_id : Nat;
        walletAddress : Principal;
        dice_1: Nat8;
        dice_2: Nat8;
        time : Int;
    };


    public type ClaimHistory = {
        id : Nat;
        name : Text;
        time : Int;
        game_id : Nat;
        icp_transfer_index : Nat;
        reward_claimed : Nat;
    };

 
    public type Game = {
        id: Nat;
        var winner : Principal;
        time_created : Int;
        var time_ended : Int;
        var reward : Nat;
        var bets : [Bet];
        
    };

    public type TicketPurchase = {
        id:Nat;
        walletAddress : ?Principal;
        time : Int;
        quantity:Nat;
        totalPrice:Nat;
        var paid:Bool;
    };

    public type DiceResult = {
        #win;
        #lose : [Nat8];
        #closed;
        #noroll;
        #transferFailed : Text;
    };

    public type TransferResult = {
        #success : Nat;
        #error : Text;

    };

    public type BookTicketResult = {
        #transferFailed : Text;
        #success : Nat;
    };

    public type User = {
        wallet : Principal;
        claimableReward : Nat;
        claimHistory : [ClaimHistory];
        purchaseHistory : [TicketPurchase];
        gameHistory : [Bet];
        availableDiceRoll : Nat;
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
