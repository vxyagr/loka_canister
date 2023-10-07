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
  admin: Principal
}) {
  private var siteAdmin : Principal = admin;
    func _isAdmin(p : Principal) : Bool {
      return (p == siteAdmin);
    };

  private var nftIndex = 0;
  private var pause = false : Bool;
  private var totalConsumedHashrate = 0;
  private var name = "Indonesia Velo";
  private var miningSiteId = 1;

  let miningContracts = Buffer.Buffer<T.MiningContract>(0); 
  let miningRewards = Buffer.Buffer<T.MiningReward>(0); 
  let lokaNFTs = Buffer.Buffer<T.LokaNFT>(0); 
  let miningSites = Buffer.Buffer<T.MiningSite>(0);


  
  public query (message) func greet() : async Text {
    return "Hello, " # Principal.toText(message.caller) # "!1";
  };

  //get all contracts owned by caller address
  public query (message) func getOwnedContracts() : async [T.NFTContract]{
      let ownedContracts = Buffer.mapFilter<T.LokaNFT,T.NFTContract >(lokaNFTs, func (nft) {
        if (nft.owner==Principal.toText(message.caller)) {

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

  //get NFT by contract ID
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


  public query (message) func getContractAmount(id_ : Nat) : async Text {
    let amount_ = miningContracts.get(id_).amount;
    Nat.toText(amount_);
  };


public shared(message) func mintContract(miningSite : Nat, amount_: Nat, duration_: Nat, durationText_ : Text, hashrate_ : Nat, elec_ : Nat, genesis_ : Nat, start_ : Nat, end_ : Nat) : async Nat {
 
    
    let miningContract_ : T.MiningContract = {
      id = nftIndex;
      amount = amount_;
      duration = duration_;
      durationText = durationText_;
      hashrate = hashrate_;
      electricityPerDay = elec_;
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
      electricityPerDay = elec_;
      hashrate = hashrate_;
      };
    miningContracts.add(miningContract_);
    lokaNFTs.add(lokaNFTs_);
    miningRewards.add(miningRewards_);
    totalConsumedHashrate += hashrate_;
    let nftName = name # " " # Nat.toText(nftIndex);
    let metadata_ :  T.Metadata = #nonfungible({name=nftName;
        asset="";
        thumbnail="";
        metadata=?#json("null");
    });
    let receiver = Principal.toText(message.caller);
    let mintRecord = (receiver, metadata_);
    let mintArgs = [mintRecord];
   let mintResult = await VELONFT.ext_mint([receiver, metadata_ ]);  
    nftIndex +=1;
    nftIndex-1;
  
};



public shared(message) func distributeBTC(amount_ : Nat, satsUsd : Nat) : async Nat {
  //assert(_isAdmin(message.caller));
  let satsPerHashrate = amount_ / totalConsumedHashrate;
  var releasedHashrate = 0;
  Buffer.iterate<T.MiningReward>(miningRewards, func (rewards) {
    if(rewards.daysLeft > 0){
    
      let remaining = rewards.daysLeft-1;
      var btcReward = rewards.hashrate*satsPerHashrate; 

      if(rewards.LETBalance > rewards.electricityPerDay){
        rewards.LETBalance -= rewards.electricityPerDay;
      }else{
        btcReward -= rewards.electricityPerDay*satsUsd;
      };
      rewards.claimableBTC += rewards.hashrate*satsPerHashrate; 
      if(remaining==0)releasedHashrate+=rewards.hashrate;
      rewards.daysLeft -=1;
    }
  });

  amount_
};

public shared(message) func distributeLOM(amount_ : Nat) : async Nat {
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




public shared(message) func claimBTC(id_ : Nat) : async Nat {

  let to_ : T.Account = {owner=message.caller};
  var miningReward_ : T.MiningReward = miningRewards.get(id_);
  var owner_ = lokaNFTs.get(id_).owner;
  var caller_ = Principal.toText(message.caller);
  let amount_ : T.Balance = miningReward_.claimableBTC;
  if (amount_<=0 or owner_!=caller_) {
    0
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
      miningReward_.claimedBTC +=amount_;
      miningRewards.put(id_,miningReward_);
      res :=1;
    };
    case (#Err(msg)) {res:=0;};
  };
  
  res;
  }
};


public shared(message) func claimLOM(id_ : Nat) : async Nat {
  let to_ : T.Account = {owner=message.caller};
  var miningReward_ : T.MiningReward = miningRewards.get(id_);
  var owner_ = lokaNFTs.get(id_).owner;
  var caller_ = Principal.toText(message.caller);
  let amount_ : T.Balance = miningReward_.claimableLOM;
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
      miningReward_.claimedLOM +=amount_;
      miningRewards.put(id_,miningReward_);
      res :=1;
    };
    case (#Err(msg)) {res:=0;};
  };

 
  res;
  }
  
};
public shared(message) func pauseContract(pause_ : Bool) : async Bool {
  //owner only
  //for as many as NFTs, loop, share as per hashrate
  let pause = pause_;
  pause_
};
  
};


