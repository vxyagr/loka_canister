import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Bool "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import M "mo:base/HashMap";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";

//import LKRC "canister:lkrc";
import LBTC "canister:lbtc";
import LKLM "canister:lklm";
import VELONFT "canister:velonft";


import T "types";
import IT "icrcTypes"


shared ({ caller = owner }) actor class VeloController({
  admin: Principal; hashrate : Float; electricity : Float; miningSiteIdparam : Nat ; siteName : Text; totalHashrate : Float; }) {


  //mining site data
  private var name = siteName;
  private var miningSiteId = miningSiteIdparam;
  private var electricityPrice = electricity; // $ per kwh
  private var hashratePrice = hashrate; // $ per 1 hashrate per day
  private var totalSiteHashrate = totalHashrate;
  //private var hardwareEfficiency = hardwareEfficiency_;
  private var hardwareEfficiency = 38.0;
  private var synced = 0;



  private var siteAdmin : Principal = admin;
  private var paused : Bool = false;
  private var nftIndex = 0;
  private var totalConsumedHashrate = 0.0;
  

  let miningContracts = Buffer.Buffer<T.MiningContract>(0); 
  let miningRewards = Buffer.Buffer<T.MiningReward>(0); 
  let lokaNFTs = Buffer.Buffer<T.LokaNFT>(0); 
  let miningSites = Buffer.Buffer<T.MiningSite>(0);

// ASSERTS
  func _isAdmin(p : Principal) : Bool {
      return (p == siteAdmin);
    };
  func _isNotPaused() : Bool {
      return paused;
    };
    
// GETTERS and CALCULATORS
  //get this canisters admin
  public query (message) func getAdmin() : async Text {
    return Principal.toText(siteAdmin);
  };

  //get all contracts owned by caller address
  public query (message) func getOwnedContracts() : async [T.NFTContract]{
      let ownedContracts = Buffer.mapFilter<T.LokaNFT,T.NFTContract >(lokaNFTs, func (nft) {
        if (nft.owner==Principal.toText(message.caller)) {
          /*backlog to do : 8 Oct 2023
          // must check if the owner if still the same as previous
          // in case of NFT has been transferred, then the owner should be altered to the new owner
          // and then return null
          */
          let nftContract : T.NFTContract = {
            id = nft.id;
            owner = nft.owner;
            amount = miningContracts.get(nft.id).amount;
            duration = miningContracts.get(nft.id).duration;
            durationText = miningContracts.get(nft.id).durationText;
            hashrate = miningContracts.get(nft.id).hashrate;
            start = miningContracts.get(nft.id).start;
            end = miningContracts.get(nft.id).end;
            electricityPerDay = miningContracts.get(nft.id).electricityPerDay;
            claimedLOM = miningRewards.get(nft.id).claimedLOM;
            claimedBTC = miningRewards.get(nft.id).claimedBTC;
            claimableBTC = miningRewards.get(nft.id).claimableBTC;
            claimableLOM = miningRewards.get(nft.id).claimableLOM;
            LETBalance = miningRewards.get(nft.id).claimedLOM;
            metadata = nft.metadata;
            daysLeft = miningRewards.get(nft.id).daysLeft;
            miningSite = miningSiteId;
          };
          ?nftContract;
        } else {
          null;
        }
      
      });
      Buffer.toArray<T.NFTContract>(ownedContracts);
  };

  //get an NFT mining contract by contract ID
  public query (message) func getNFTContract(id_ : Nat) : async T.NFTContract{
      let nft = lokaNFTs.get(id_);
      let nftContract : T.NFTContract = {
          id = nft.id;
          owner = nft.owner;
          amount = miningContracts.get(nft.id).amount;
          duration = miningContracts.get(nft.id).duration;
          durationText = miningContracts.get(nft.id).durationText;
          hashrate = miningContracts.get(nft.id).hashrate;
          start = miningContracts.get(nft.id).start;
          end = miningContracts.get(nft.id).end;
          electricityPerDay = miningContracts.get(nft.id).electricityPerDay;
          claimedLOM = miningRewards.get(nft.id).claimedLOM;
          claimedBTC = miningRewards.get(nft.id).claimedBTC;
          claimableBTC = miningRewards.get(nft.id).claimableBTC;
          claimableLOM = miningRewards.get(nft.id).claimableLOM;
          LETBalance = miningRewards.get(nft.id).LETBalance;
          metadata = nft.metadata;
          daysLeft = miningRewards.get(nft.id).daysLeft;
          miningSite = miningSiteId;
      };

      nftContract;
  };


  //helper function, should have been separated in another .mo but well im busy
  private func natToFloat (nat_ : Nat ) : Float {
    let toNat64_ = Nat64.fromNat(nat_);
    let toInt64_ = Int64.fromNat64(toNat64_);
    let amountFloat_ = Float.fromInt64(toInt64_);
    return amountFloat_;
  };

  //calculate how much TH/s or hashrate given the amount and duration of mining
  private func calculateHashrate(amount_ : Nat, duration_ : Nat, satsUSD : Float) : Float{

    let satsPerHashDay : Float = 240.0;
    let amountFloat_ = natToFloat(amount_);
    let base2YearsTHperDay = amountFloat_ / (28*24) / hashratePrice / (1-70/100);
    let durationROIFactor = switch (duration_){
      case (1) 20;
      case (6) 70;
      case (12) 80;
      case (24) 100;
      case _ 0;  
    };
    //Debug.print("calculate");
    //Debug.print("ROI "#Nat.toText(durationROIFactor));
    let dRFFloat_ = natToFloat(durationROIFactor);
    let durationFloat_ = natToFloat(duration_);
    let sats2Years = base2YearsTHperDay * satsPerHashDay * (28*24);
    let baseUSDProfit = sats2Years * satsUSD - amountFloat_;
    let baseMonthlyUSDProfit = baseUSDProfit / 24;
    //Debug.print("Profit "#Float.toText(baseMonthlyUSDProfit));
    let finalSats =
        ((dRFFloat_/ 100) * baseMonthlyUSDProfit * durationFloat_ + amountFloat_) / satsUSD;
    //Debug.print("Final sats "#Float.toText(finalSats));
    let thRented : Float = finalSats / (durationFloat_ * 28) / satsPerHashDay;

    return thRented;
  };

  //calculate how much electricity cost per day given the hashrate usage
  private func calculateElectricityConsumptionPerDay(th_ : Float) : Float{
    let electricityCostPerDay = ((th_ * hardwareEfficiency *24)/1000) * electricityPrice;
    return electricityCostPerDay;
  };


//SETTERS / UPDATE / MINTER and CLAIM FUNCTIONS


  //a function to synchronize NFT owner and mining contract owner, should be called automatically every 24 hrs
  public shared(message) func syncOwner() : async Nat {
    assert(_isAdmin(message.caller));
    return 1
  };

  public shared(message) func manualSync() : async Nat {
    /* backlog to do 8 Oct 2023
    //get list of NFTs owned by caller
    //check with controllers list of owner
    //if different, change to the latest NFT canister owner
    */
    return 1
  };

  //the main function of this canister, minting a mining contract
  public shared(message) func mintContract(amount_: Nat, duration_: Nat, durationText_ : Text, genesis_ : Nat, start_ : Nat, end_ : Nat, satsUSD : Float) : async Nat {
  
      
      let calculatedHashrate = calculateHashrate(amount_, duration_, satsUSD);
      let calculatedElectricityerDay = calculateElectricityConsumptionPerDay(calculatedHashrate);

      let miningContract_ : T.MiningContract = {
        id = nftIndex;
        amount = amount_;
        duration = duration_;
        durationText = durationText_;
        hashrate = calculatedHashrate;
        electricityPerDay = calculatedElectricityerDay;
        genesisId = genesis_;
        start = start_;
        end = end_;
        };
      let lokaNFTs_ : T.LokaNFT = {
        id = nftIndex;
        var owner = Principal.toText(message.caller);
        metadata = "";
        
      };
      let miningRewards_ : T.MiningReward = {
        id = nftIndex;   
        var claimedBTC = 0;
        var claimableBTC = 0;
        var claimableLOM = 0;
        var claimedLOM = 0;
        var daysLeft = duration_;
        var LETBalance = 0;
        var staked = false;
        var stakeTime = 0;
        electricityPerDay = calculatedElectricityerDay;
        hashrate = calculatedHashrate;
        };
      miningContracts.add(miningContract_);
      lokaNFTs.add(lokaNFTs_);
      miningRewards.add(miningRewards_);
      totalConsumedHashrate += calculatedHashrate;
      let nftName = name # " " # Nat.toText(nftIndex);

      let receiver = Principal.toText(message.caller);
      Debug.print("minting to  "#receiver);
      let mintRecord = (receiver, #nonfungible({name=nftName;
          asset="";
          thumbnail="";
          metadata=?#json("null");
      }));
      let mintArgs = [mintRecord];
      let mintResult = await VELONFT.ext_mint(mintArgs);  
      //Debug.print("minted "#Nat.toText(Array.size(mintResult)));
      nftIndex +=1;
      nftIndex-1;
    
  };

  //will be deleted
  
  public shared(message) func testMint(owner_ : Principal) : async Nat {
    assert(_isAdmin(message.caller));
      let nftName = name # " " # Nat.toText(nftIndex);

      let receiver = Principal.toText(owner_);
      //Debug.print("minting to  "#receiver);
      let mintRecord = (receiver, #nonfungible({name=nftName;
          asset="";
          thumbnail="";
          metadata=?#json("null");
      }));
      let mintArgs = [mintRecord];
      let mintResult = await VELONFT.ext_mint(mintArgs);  
      1;
  };
  


  //being called by site admin only, to distribute ckBTC every certain period
  public shared(message) func distributeBTC(amount_ : Float, satsUsd : Float) : async Float {
    //assert(_isAdmin(message.caller));
    let satsPerHashrate = amount_ / totalConsumedHashrate;
    var releasedHashrate = 0.0;
    Buffer.iterate<T.MiningReward>(miningRewards, func (rewards) {
      if(rewards.daysLeft > 0){
      
        let remaining = rewards.daysLeft-1;
        var btcReward = rewards.hashrate*satsPerHashrate; 

        if(rewards.LETBalance > rewards.electricityPerDay){
          rewards.LETBalance -= rewards.electricityPerDay;
        }else{
          btcReward -= rewards.electricityPerDay*satsUsd;
        };
        rewards.claimableBTC += Float.floor(rewards.hashrate*satsPerHashrate); 
        if(remaining==0)releasedHashrate+=rewards.hashrate;
        rewards.daysLeft -=1;
      }
    });

    amount_
  };

  //being called by site admin only, to distribute LOM native token every certain period
  public shared(message) func distributeLOM(amount_ : Float) : async Float {
    //assert(_isAdmin(message.caller));
    let satsPerHashrate = amount_ / totalConsumedHashrate;
    var releasedHashrate = 0;
    Buffer.iterate<T.MiningReward>(miningRewards, func (rewards) {
      if(rewards.daysLeft > 0){
      rewards.claimableLOM += rewards.hashrate*satsPerHashrate; 
      }
    });
    amount_
  };

  public shared(message) func rechargeLET(id_ : Nat, amount_ : Nat) : async Nat {
    
    1
  };



  //being called by end user / retail from web, to claim ckBTC to their wallet
  public shared(message) func claimBTC(id_ : Nat) : async Nat {

    let to_ : T.Account = {owner=message.caller};
    var miningReward_ : T.MiningReward = miningRewards.get(id_);
    var owner_ = lokaNFTs.get(id_).owner;
    var caller_ = Principal.toText(message.caller);
    let temp = miningReward_.claimableBTC;
    let amt64 = Float.toInt64(miningReward_.claimableBTC);
    let amount64_ = Int64.toNat64(amt64);
    let amount_ : T.Balance = Nat64.toNat(amount64_);
    if (amount_<=0 or owner_!=caller_) {
      1
    }else{
    let transferResult = await LBTC.icrc1_transfer({
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=message.caller; subaccount=null};
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
        miningReward_.claimableBTC := 0;
        miningReward_.claimedBTC +=temp;
        miningRewards.put(id_,miningReward_);
        res :=2;
      };
      case (#Err(msg)) {
        //let ms : Text  = msg;
        Debug.print("transfer error  ");
        switch (msg){
          case (#BadFee(number)){
            Debug.print("Bad Fee");
          };
          case (#GenericError(number)){
            Debug.print("err "#number.message);
          };
          case (#InsufficientFunds(number)){
            Debug.print("insufficient funds");
          };
        };
        res:=0;
        };
    };
    
    res;
    }
  };

  //being called by end user / retail from web, to claim LOM to their wallet
  public shared(message) func claimLOM(id_ : Nat) : async Nat {
    let to_ : T.Account = {owner=message.caller};
    var miningReward_ : T.MiningReward = miningRewards.get(id_);
    var owner_ = lokaNFTs.get(id_).owner;
    var caller_ = Principal.toText(message.caller);
    let temp = miningReward_.claimableLOM;
    let amt64 = Float.toInt64(miningReward_.claimableBTC);
    let amount64_ = Int64.toNat64(amt64);
    let amount_ : T.Balance = Nat64.toNat(amount64_);

    if (amount_<=0 or owner_!=caller_) {
      0
    }else{
    let transferResult = await LKLM.icrc1_transfer({
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=message.caller; subaccount=null};
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
        miningReward_.claimableLOM := 0;
        miningReward_.claimedLOM +=temp;
        miningRewards.put(id_,miningReward_);
        res :=1;
      };
      case (#Err(msg)) {res:=0;};
    };

  
    res;
    }
    
  };

  //pause / resume contract by setting paused  variable value
  public shared(message) func pauseContract(pause_ : Bool) : async Bool {
    assert(_isAdmin(message.caller));
    //for as many as NFTs, loop, share as per hashrate
    let paused = pause_;
    pause_
  };
    
};


