import Time "mo:base/Time";
//import Principal "motoko/util/Principal";


module {

    public type Token = Principal;

    public type OrderId = Nat32;

    public type TransactionHistory = {
        id: Nat;
        caller: Text;
        time : Time.Time;
        action: Text;
        amount: Nat;
    };

    public type Account = {
        owner : Principal;
        //subaccount : ?Subaccount;
    };
    public type Balance = Nat;
     public type Subaccount = Blob;
     public type TransferArgs = {
        from_subaccount : ?Subaccount;
        to : Account;
        amount : Balance;
        fee : ?Balance;
        memo : ?Blob;

        /// The time at which the transaction was created.
        /// If this is set, the canister will check for duplicate transactions and reject them.
        created_at_time : ?Nat64;
    };

    public type Duration = {#seconds : Nat; #nanoseconds : Nat};

    public type NFTContract = {
        id : Nat;
        amount : Nat;
        duration : Nat;
        durationText : Text;
        hashrate : Float;
        start : Int;
        end : Int;
        electricityPerDay : Float;
        claimedLOM : Float;
        claimedBTC : Float;
        claimableBTC : Float;
        claimableLOM : Float;
        LETBalance : Float;
        owner : Text;
        metadata : Text;
        daysLeft : Int;
        miningSite : Nat;
        //canister : Principal;
    };

    
    public type MiningSiteStatus = {
        id : Nat;
        var status : Bool;
    };
    
    public type MiningSite = {
        id : Nat;
        location : Text;
        name : Text;
        totalHashrate : Nat;
        dollarPerHashrate : Float;
        electricityPerKwh : Float;
        nftCanisterId : Text;
        controllerCanisterId : Text;
    };

    public type MiningContract = {
        id : Nat;
        amount : Nat;
        durationText : Text;
        duration: Nat;      
        hashrate : Float;     
        genesisId: Nat;
        start: Int;
        end : Int;
        electricityPerDay: Float;       

    };

    public type LokaNFT = {
        id : Nat;
        metadata : Text;
        var owner : Text;
        
    };
    

    public type MiningReward = {
        id : Nat;
        var claimableBTC : Float;
        var claimedBTC : Float;
        var claimableLOM : Float;
        var claimedLOM : Float;
        var daysLeft : Int;
        hashrate : Float;
        var LETBalance : Float;
        electricityPerDay: Float;
        var staked : Bool;
        var stakeTime : Nat;
        start : Int;
        end : Int;
    };

    public type Genesis = {
        id : Nat;
        owner : Principal;
        claimableLOM : Nat;
    };

    
  public type MetadataValue = (Text , {
        #text : Text;
        #blob : Blob;
        #nat : Nat;
        #nat8: Nat8;
    });

    public type MetadataContainer = {
      #data : [MetadataValue];
      #blob : Blob;
      #json : Text;
    };

    public type NNWB = Nat;

    public type Metadata = {
        #fungible : {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        metadata: ?MetadataContainer;
        };
        #nonfungible : {
        name : Text;
        asset : Text;
        thumbnail : Text;
        metadata: ?MetadataContainer;
        };
    };
    
};
