import Time "mo:base/Time";


module {

    public type Token = Principal;

    public type OrderId = Nat32;

    /*
    CLASSES
    1. Mining Contract
    id
    amount
    genesis id
    duration
    TH
    start
    end
    electricity per day
    LET balance
    claimed BTC
    claimed LOM

    */
     public type TransactionHistory = {
        id: Nat;
        caller: Text;
        time : Nat;
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

    public type NFTContract = {
        id : Nat;
        amount : Nat;
        duration : Nat;
        durationText : Text;
        hashrate : Nat;
        start : Nat;
        end : Nat;
        electricityPerDay : Nat;
        claimedLOM : Nat;
        claimedBTC : Nat;
        claimableBTC : Nat;
        claimableLOM : Nat;
        LETBalance : Nat;
        owner : Text;
        metadata : Text;
        daysLeft : Nat;
        miningSite : Nat;
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
        hashrate : Nat;     
        genesisId: Nat;
        start: Nat;
        end : Nat;
        electricityPerDay: Nat;       

    };

    public type LokaNFT = {
        id : Nat;
        metadata : Text;
        var owner : Text;
        
    };
    

    public type MiningReward = {
        id : Nat;
        var claimableBTC : Nat;
        var claimedBTC : Nat;
        var claimableLOM : Nat;
        var claimedLOM : Nat;
        var daysLeft : Nat;
        hashrate : Nat;
        var LETBalance : Nat;
        electricityPerDay: Nat;
        var staked : Bool;
        var stakeTime : Nat;
    };

    public type Genesis = {
        id : Nat;
        owner : Principal;
        claimableLOM : Nat;
    }

    
  
    
}
