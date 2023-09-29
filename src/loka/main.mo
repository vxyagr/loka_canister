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

import LKRC "canister:lkrc";
import LBTC "canister:lbtc";
import LKLM "canister:lklm";


import T "types";


actor {

  /*
  VARIABLES AND OBJECTS

      STABLE VARIABLES AND OBJECTS
      1. Mining Contract NFT list
      2. Mining Contract NFT indexed by principal
      3. Claimable BTC list
      4. Claimable LOM list
      5. BTC distributed
      6. BTC claimed
      7. LOM distributed
      8. LOM claimed
      9. Genesis NFT list


      1. Mining Site ID
      2. Mining Site Canister
      3. Available hashrate
      4. BTC mined
      5. BTC distributed
      6. BTC claimed
      7. Distribution History
      8. Claim History
      9. Transaction History
      10. Collateral Vault

  */
  private var nftIndex = 0;
  private var pause = false : Bool;
  private var totalConsumedHashrate = 0;

  let miningContracts = Buffer.Buffer<T.MiningContract>(0); 
  let miningRewards = Buffer.Buffer<T.MiningReward>(0); 
  let lokaNFTs = Buffer.Buffer<T.LokaNFT>(0); 


  /*
  FUNCTIONS

  GETTER

  1. Get Contract NFT Metadata
  2. Get Owner of a contract
  3. Get Owned Contracts
  4. Get Transaction history of a contract (mint, transfer, claim, recharge)
  5. Get transaction history of a principal
  6. Get total claimed BTC of a principal
  7. Get total claimed BTC of a contract
  8. Get remaining LET
  9. Get remaining mining days
  */
  public query (message) func greet() : async Text {
    return "Hello, " # Principal.toText(message.caller) # "!1";
  };

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
          };
          ?nftContract;
        } else {
          null;
        }
      
      });
      Buffer.toArray<T.NFTContract>(ownedContracts);
  };


  public query (message) func getNFTContract(id_ : Nat) : async T.NFTContract{
      let nft = lokaNFTs.get(id_);
      //Buffer.mapFilter<T.LokaNFT,T.NFTContract >(lokaNFTs, func (nft) {
        //if (nft.owner==Principal.toText(message.caller)) {

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
          };
          //?nftContract;
        //} else {
        //  null;
       // }
      
      //});
      nftContract;
  };

  /*public query (message) func getContract(id_ : Nat) : async T.MiningContract{
      let miningContract_ = miningContracts.get(id_);
      miningContract_;
  };*/

  public query (message) func getContractAmount(id_ : Nat) : async Text {
    let amount_ = miningContracts.get(id_).amount;
    Nat.toText(amount_);
  };
  /*

  SETTER
  1. Mint (amount, genesis id, duration), pay using ICP
  2. Transfer (id, from, to)
  3. DistributeBTC (BTC amount)
  4. ClaimBTC
  5. DistributeLOM
  6. ClaimLOM
  7. Recharge
  8. Mint Genesis

  */
public shared(message) func mintContract(amount_: Nat, duration_: Nat, durationText_ : Text, hashrate_ : Nat, elec_ : Nat, genesis_ : Nat, start_ : Nat, end_ : Nat) : async Nat {
  if(pause){
    0
  }else{
    
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
    
    nftIndex +=1;
    nftIndex-1;
  }
};

public shared(message) func distributeBTC(amount_ : Nat, satsUsd : Nat) : async Nat {
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
  //owner only
  //for as many as NFTs, loop, share as per hashrate
  //write to history
  amount_
};

public shared(message) func distributeLOM(amount_ : Nat) : async Nat {
  let satsPerHashrate = amount_ / totalConsumedHashrate;
  var releasedHashrate = 0;
  Buffer.iterate<T.MiningReward>(miningRewards, func (rewards) {
    if(rewards.daysLeft > 0){
    rewards.claimableLOM += rewards.hashrate*satsPerHashrate; 
    }
  });
  //owner only
  //for as many as NFTs, loop, share as per hashrate
  //write to history
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

  miningReward_.claimableBTC := 0;
  miningReward_.claimedBTC +=amount_;
  miningRewards.put(id_,miningReward_);

  1}
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

  miningReward_.claimableLOM := 0;
  miningReward_.claimedLOM +=amount_;
  miningRewards.put(id_,miningReward_);

  1}
  
};
public shared(message) func pauseContract(pause_ : Bool) : async Bool {
  //owner only
  //for as many as NFTs, loop, share as per hashrate
  let pause = pause_;
  pause_
};
  
};


/*actor {

  public func greet(name : Text) : async Text {
    return "Hello, " # name # "!";
  };

};
*/