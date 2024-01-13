import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Random "mo:base/Random";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Bool "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Char "mo:base/Char";
import { now } = "mo:base/Time";
import { abs } = "mo:base/Int";
import Account = "./account";
import { setTimer; cancelTimer; recurringTimer } = "mo:base/Timer";
import T "types";
import ICPLedger "canister:icp_ledger_canister";
//import ICPLedger "canister:icp_test";
//import Eyes "canister:eyes";
//import CKBTC "canister:ckbtc_ledger";
//import LBTC "canister:lbtc";

shared ({ caller = owner }) actor class ICDragon({
  admin: Principal
}) =this{
  //indexes
  
  private var siteAdmin : Principal = admin;
  private var dappsKey = "0xSet";

  
  
  stable var devPool : Principal = admin; 
  stable var rewardPool : Principal = admin; 

  //@dev--users
  private stable var gameIndex = 0;
  private stable var firstGameStarted = false;
  private stable var transactionIndex = 0;
  private stable var betIndex = 0;
  private stable var ticketIndex = 0;
  private stable var pause = false : Bool;
  private stable var ticketPrice =   50000000;
  private stable var eyesToken = false;
  private stable var eyesTokenDistribution = 10000000;
  private stable var eyesDays = 0;
  private stable var initialReward = 500000000;
  private stable var initialBonus = 50000000;
  stable var nextTicketPrice = 50000000;

  private var userTicketQuantityHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userDoubleRollQuantityHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userTicketPurchaseHash = HashMap.HashMap<Text, [T.PaidTicketPurchase]>(0, Text.equal, Text.hash);
  private var userClaimableHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userClaimHistoryHash = HashMap.HashMap<Text, [T.ClaimHistory]>(0, Text.equal, Text.hash);
  private var userBetHistoryHash = HashMap.HashMap<Text, [T.Bet]>(0, Text.equal, Text.hash);
  var bonusPoolbyWallet = HashMap.HashMap<Text, [Nat]>(0, Text.equal, Text.hash);

  //@dev--variables and history
  var games = Buffer.Buffer<T.Game>(0);
  var ticketPurchaseHistory = Buffer.Buffer<T.TicketPurchase>(0);
  var betHistory = Buffer.Buffer<T.Bet>(0);
  

  //upgrade temp params
  stable var games_ : [T.Game]= []; // for upgrade
  stable var ticketPurchaseHistory_ : [T.TicketPurchase]= []; // for upgrade 
  stable var betHistory_ : [T.Bet] = [];

  stable var userTicketQuantityHash_ : [(Text,Nat)] = []; 
  stable var userDoubleRollQuantityHash_ : [(Text,Nat)] = []; 
  stable var userTicketPurchaseHash_ : [(Text,[T.PaidTicketPurchase])] = []; 
  stable var userClaimableHash_ : [(Text, Nat)] = [];
  stable var userClaimHistoryHash_ : [(Text, [T.ClaimHistory])] = [];
  stable var userBetHistoryHash_ : [(Text,[T.Bet])]=[];

  stable var bonusPoolbyWallet_ : [(Text,[Nat])]=[];
  //stable var transactionHash


  system func preupgrade() {
        games_ := Buffer.toArray<T.Game>(games);
        ticketPurchaseHistory_ := Buffer.toArray<T.TicketPurchase>(ticketPurchaseHistory);   
        betHistory_ := Buffer.toArray<T.Bet>(betHistory); 

        userTicketQuantityHash_ := Iter.toArray(userTicketQuantityHash.entries());
        userTicketPurchaseHash_ := Iter.toArray(userTicketPurchaseHash.entries());
        userClaimableHash_ := Iter.toArray(userClaimableHash.entries());
        userClaimHistoryHash_ := Iter.toArray(userClaimHistoryHash.entries());
        userBetHistoryHash_ := Iter.toArray(userBetHistoryHash.entries());
  };
  system func postupgrade() {
        games := Buffer.fromArray<T.Game>(games_); 
        ticketPurchaseHistory := Buffer.fromArray<T.TicketPurchase>(ticketPurchaseHistory_);
        betHistory := Buffer.fromArray<T.Bet>(betHistory_);

        userTicketQuantityHash := HashMap.fromIter<Text, Nat>(userTicketQuantityHash_.vals(), 1, Text.equal, Text.hash);
        userDoubleRollQuantityHash := HashMap.fromIter<Text, Nat>(userDoubleRollQuantityHash_.vals(), 1, Text.equal, Text.hash);
        userTicketPurchaseHash := HashMap.fromIter<Text, [T.PaidTicketPurchase]>(userTicketPurchaseHash_.vals(), 1, Text.equal, Text.hash);
        userClaimableHash := HashMap.fromIter<Text, Nat>(userClaimableHash_.vals(), 1, Text.equal, Text.hash);
        userClaimHistoryHash := HashMap.fromIter<Text, [T.ClaimHistory]>(userClaimHistoryHash_.vals(), 1, Text.equal, Text.hash);
        userBetHistoryHash := HashMap.fromIter<Text, [T.Bet]>(userBetHistoryHash_.vals(), 1, Text.equal, Text.hash);
        
  };

  //@dev timers initialization
   var halving = ignore recurringTimer(#seconds (24*60*60*10),  func () : async () {
      if(eyesToken){
        eyesTokenDistribution := eyesTokenDistribution/2;
        eyesDays+=1;
        //if(EyesDays==30)EyesToken:=false;
      };
  });

 

  public shared(message) func clearData() : async (){
    assert(_isAdmin(message.caller));

    gameIndex :=0;
    transactionIndex :=0;
    firstGameStarted:=false;
    //initialReward = 50000
    betIndex:=0;
    ticketIndex := 0;
    ticketPrice := 5_000_000;
    eyesToken := false;
    eyesTokenDistribution := 100_000_000_000;
    eyesDays := 0;


    games := Buffer.Buffer<T.Game>(0);
    ticketPurchaseHistory := Buffer.Buffer<T.TicketPurchase>(0);
    betHistory := Buffer.Buffer<T.Bet>(0);
    
    userTicketQuantityHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    userTicketPurchaseHash := HashMap.HashMap<Text, [T.PaidTicketPurchase]>(0, Text.equal, Text.hash);
    userClaimableHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    userClaimHistoryHash := HashMap.HashMap<Text, [T.ClaimHistory]>(0, Text.equal, Text.hash);
    userBetHistoryHash := HashMap.HashMap<Text, [T.Bet]>(0, Text.equal, Text.hash);

    
    
  };

  public shared(message) func withdrawICP(amount_ : Nat, p_ : Principal) : async Bool {
    assert(_isAdmin(message.caller));
    let res =    transfer(amount_, p_);
    true;
  };

  private func natToFloat (nat_ : Nat ) : Float {
    let toNat64_ = Nat64.fromNat(nat_);
    let toInt64_ = Int64.fromNat64(toNat64_);
    let amountFloat_ = Float.fromInt64(toInt64_);
    return amountFloat_;
  };

  func _isAdmin(p : Principal) : Bool {
      return (p == siteAdmin);
    };

  func _isApp(key : Text) : Bool {
      return (key == dappsKey);
  };

  func _isNotPaused(): Bool {
    if(pause)return false;
    true;
  };

  public query func isNotPaused(): async Bool {
    if(pause)return false;
    true;
  };

  public shared(message) func setDevPool(vault_ : Principal) : async Principal {
    assert(_isAdmin(message.caller));
    devPool := vault_;
    vault_;
  };

  public shared(message) func setRewardPool(vault_ : Principal) : async Principal {
    assert(_isAdmin(message.caller));
    rewardPool := vault_;
    vault_;
  };

  public shared(message) func setEyesToken(active_ : Bool) : async Bool {
    assert(_isAdmin(message.caller));
    eyesToken := active_;
    eyesToken;
  };

  public query(message) func getDevPool() : async Principal {
    devPool;
  };

  public query(message) func getRewardPool() : async Principal {
    rewardPool;
  };

  public query(message) func getTicketPrice() : async Nat {
    ticketPrice;
  };
  
  public shared(message) func setTicketPrice(price_ : Nat) : async Nat {
    assert(_isAdmin(message.caller));
    ticketPrice := price_ ;
    ticketPrice;
  };

  public shared(message) func setNextTicketPrice(price_ : Nat) : async Nat {
    assert(_isAdmin(message.caller));
    nextTicketPrice := price_ ;
    price_;
  };

  public shared(message) func setAdmin(admin_ : Principal) : async Principal {
    assert(_isAdmin(message.caller));
    siteAdmin := admin_ ;
    siteAdmin;
  };

  public query(message) func getCurrentIndex() : async Nat {
    gameIndex;
  };

  public shared(message) func getUserData() : async T.User{
    var claimHistory_ = userClaimHistoryHash.get(Principal.toText(message.caller));
    var claimHistory : [T.ClaimHistory] = [];
    switch(claimHistory_){
      case (?c){
        claimHistory := c;
      };
      case (null){
        claimHistory := []; 
      }
    };
    var claimable_ = userClaimableHash.get(Principal.toText(message.caller));
    var claimable : Nat = 0;
    switch(claimable_){
      case (?c){
        claimable := c;
      };
      case (null){
        claimable :=0; 
      }
    };
    var purchase_ = userTicketPurchaseHash.get(Principal.toText(message.caller));
    var purchase : [T.PaidTicketPurchase] = [];
    switch(purchase_){
      case (?p){
        purchase := p;
      };
      case (null){
        //Debug.print("no purchase yet"); 
      }
    };
    var bets_ = userBetHistoryHash.get(Principal.toText(message.caller));
    var bets : [T.Bet] = [];
    switch(bets_){
      case (?b){
        bets := b;
      };
      case (null){
        //Debug.print("no bet yet"); 
      }
    };
    var remaining : Nat= 0;
    switch (userTicketQuantityHash.get(Principal.toText(message.caller))) {
      case (?x) {
        remaining := x;
      };
      case (null) {
        remaining :=0;
        userTicketQuantityHash.put(Principal.toText(message.caller),0);
      };
    };
    var doubleRollRemaining : Nat= 0;
    switch (userDoubleRollQuantityHash.get(Principal.toText(message.caller))) {
      case (?x) {
        doubleRollRemaining := x;
      };
      case (null) {
        doubleRollRemaining :=0;
        userDoubleRollQuantityHash.put(Principal.toText(message.caller),0);
      };
    };
   

    let userData_ : T.User = {
      walletAddress = message.caller; 
      claimableReward = claimable;
      claimHistory = claimHistory;
      purchaseHistory = purchase;
      gameHistory = bets;
      availableDiceRoll = remaining + doubleRollRemaining;
      claimableBonus =  await checkBonusPool(message.caller);
    };
    //return user data
    userData_;
  };

  public query(message) func checkBonusPool(p_ : Principal) : async [T.GameBonus]{
    //return game data
    let listGameBonusId_ = bonusPoolbyWallet.get(Principal.toText(p_));
    var gameBonus_ : [T.GameBonus] = [];
    switch (listGameBonusId_) {
      case (?n) {
       for (i in n.vals()) {
          let game_ = games.get(i);
          if(game_.bonus_claimed==false and game_.time_ended > 0){
            let bonus_ : T.GameBonus = {id = i;bonus = game_.bonus;};
            gameBonus_ := Array.append<T.GameBonus>(gameBonus_, [bonus_]);
          }
        };
        return gameBonus_;
      };
      case (null) {
        return [];
      };
    };

    let currentGame_ = games.get(gameIndex);
    let game_ : T.CurrentGame = {
           bets = currentGame_.bets;
           id = currentGame_.id;
           reward = currentGame_.reward;
           reward_text = Nat.toText(currentGame_.reward);
           time_created =currentGame_.time_created;
           time_ended =currentGame_.time_ended;
           winner = currentGame_.winner;
           bonus = currentGame_.bonus;
         };
    [];
  };

  public query(message) func getCurrentGame() : async T.GameCheck{
    //return game data
    if(firstGameStarted==false) return #none;
    let currentGame_ = games.get(gameIndex);
    Debug.print("current game reward "#Nat.toText(currentGame_.reward));
    
    let game_ : T.CurrentGame = {
           bets = currentGame_.bets;
           id = currentGame_.id;
           reward = currentGame_.reward;
           reward_text = Nat.toText(currentGame_.reward);
           time_created =currentGame_.time_created;
           time_ended =currentGame_.time_ended;
           winner = currentGame_.winner;
           bonus = currentGame_.bonus;
         };
    #ok(game_);
  };

  public shared(message) func pauseCanister(pause_ : Bool) : async Bool {
    assert(_isAdmin(message.caller));
    pause :=pause_;
    pause_;
  } ;

  //@dev--to buy ticket, user should call approve function on icrc2
  public shared(message) func buy_ticket(quantity_ : Nat, ticketPrice : Nat, totalPrice_ : Nat) : async T.BookTicketResult {
    //set teh variable
    
    
    //Pay by calling icrc2 transfer from
    let transferRes_ = await transferFrom(message.caller,totalPrice_);
    var transIndex_ = 0;
    switch transferRes_ {
      case (#success(x)) { transIndex_ := x; };
      case (#error(txt)) {
        Debug.print("error "#txt );
        return #transferFailed(txt);
      }
    };
    //assert(transIndex_!=0);
    //write to ticket book history
    let ticketBook_ : T.TicketPurchase = {id=ticketIndex;walletAddress=?message.caller;time=now();quantity=quantity_;totalPrice=totalPrice_;var icp_index=transIndex_;};
    let ticketBookPaid_ : T.PaidTicketPurchase = {id=ticketIndex;walletAddress=?message.caller;time=now();quantity=quantity_;totalPrice=totalPrice_;icp_index=transIndex_;};
    ticketPurchaseHistory.add(ticketBook_);
    let ticketBookNow_ = ticketPurchaseHistory.get(ticketIndex);
    ticketIndex+=1;
    //write to users hash, both history and remaining ticket hash
    let userTickets_ = userTicketPurchaseHash.get(Principal.toText(message.caller));
    switch (userTickets_) {
      case (?x) {
        userTicketPurchaseHash.put(Principal.toText(message.caller), Array.append<T.PaidTicketPurchase>(x, [ticketBookPaid_]));
      };
      case (null) {
        userTicketPurchaseHash.put(Principal.toText(message.caller), [ticketBookPaid_]);
      };
    };
    let userRemainingTicket_ = userTicketQuantityHash.get(Principal.toText(message.caller));
    switch (userRemainingTicket_) {
      case (?x) {
        userTicketQuantityHash.put(Principal.toText(message.caller), x+quantity_);
      };
      case (null) {
        userTicketQuantityHash.put(Principal.toText(message.caller), quantity_);
      };
    };

    
    
    #success(quantity_);
  } ;

 
  //@dev-- called to start game for the first time by admin
  public shared(message) func firstGame() : async  Bool {
    assert(_isAdmin(message.caller));
    ticketPrice:=500000;
    initialReward :=ticketPrice*10;
    initialBonus :=ticketPrice;
    
    assert(gameIndex==0);
    assert(firstGameStarted==false);
    Debug.print("Starting new game ");
    let newGame : T.Game = {id = gameIndex; var totalBet = 0; var winner = siteAdmin; time_created = now(); var time_ended=0; var reward=initialReward; var bets = []; var bonus=initialBonus; var bonus_winner=siteAdmin; var bonus_claimed=false;};
    games.add(newGame);
    firstGameStarted:=true;
    let allgame = games.size();
    true;
  };

  func startNewGame(){
    gameIndex +=1;
    ticketPrice := nextTicketPrice;
    let newGame : T.Game = {id = gameIndex; var totalBet = 0;var winner = siteAdmin; time_created = now(); var time_ended=0; var reward=initialReward; var bets = [];var bonus=initialBonus; var bonus_winner=siteAdmin; var bonus_claimed=false;};
    games.add(newGame);

  };

  func roll() : async Nat8 {
      let random = Random.Finite(await Random.blob());
      let dice_ = random.binomial(5) ;
      switch (dice_) {
      case (?x) {
        return x+1;
      };
      case (null) {
        return 2;
      };
    };
  };

  public shared(message) func roll_dice(game_id : Nat) : async T.DiceResult {
    //get game data
    let game_ = games.get(game_id);
    let gameBets_ = game_.bets;
    var remaining_ : Nat= 0;
    var doubleRollRemaining_ : Nat=0;
    Debug.print("check remaining");
    //get remaining dice roll ticket
    switch (userDoubleRollQuantityHash.get(Principal.toText(message.caller))) {
      case (?x) {
        doubleRollRemaining_ := x;
      };
      case (null) {
        remaining_:=0;
        userDoubleRollQuantityHash.put(Principal.toText(message.caller),0);
      };
    };


    switch (userTicketQuantityHash.get(Principal.toText(message.caller))) {
      case (?x) {
        remaining_ := x;
      };
      case (null) {
        remaining_:=0;
        userTicketQuantityHash.put(Principal.toText(message.caller),0);
      };
    };
    //check if the game is already won and closed
    if (game_.time_ended!=0)return #closed;
    //check if there is a ticket remaining
    if (remaining_+doubleRollRemaining_==0)return #noroll;
    
    var extraRoll_ = false;
    //ICP send 50% of ticket price to holder
    if(doubleRollRemaining_ == 0){
      let mt = ticketPrice/2;
      Debug.print("transferring to dev"#Nat.toText(mt));
      let transferResult_ = await transfer(mt,devPool);
      var transferred=false;
      switch transferResult_ {
        case (#success(x)) { transferred := true; };
        case (#error(txt)) {
          Debug.print("error "#txt );
          return #transferFailed(txt);
        }
      };
          //substract ticket
      userTicketQuantityHash.put(Principal.toText(message.caller), remaining_-1);
      extraRoll_ :=true;
    }else{
          //substract ticket
      userDoubleRollQuantityHash.put(Principal.toText(message.caller), doubleRollRemaining_ -1);
    };
    //ROLL!==============================================================================================

    
    
    let dice_1_ = await roll();
    let dice_2_ = await roll();
    //check if Token started, mint Eyes to address based on emission halving
    if(eyesToken and extraRoll_){
      //let res_ = transferEyesToken(message.caller, Nat8.toNat(dice_1_ + dice_2_));
    };

    //write bet history to : history variable, user hash, and to game object (thats 3 places)
    let bet_ : T.Bet = {id = betIndex; game_id = gameIndex; dice_1 = dice_1_;dice_2=dice_2_;walletAddress=message.caller;time=now()} ;
    betIndex +=1;
    var userBets_ = userBetHistoryHash.get(Principal.toText(message.caller));
    switch (userBets_){
      case(?u){
        userBetHistoryHash.put(Principal.toText(message.caller),Array.append<T.Bet>(u, [bet_]));
      };
      case(null){
        userBetHistoryHash.put(Principal.toText(message.caller),[bet_]);
      }
    };
    betHistory.add(bet_);
    game_.bets := Array.append<T.Bet>(gameBets_, [bet_]);
    //check roll result
    if(dice_1_==dice_2_ and dice_1_==1){
      Debug.print("win!");
      //distribute reward
      let userReward_ = userClaimableHash.get(Principal.toText(message.caller));
      switch (userReward_){
        case(?r){
          userClaimableHash.put(Principal.toText(message.caller),r+game_.reward);
        };
        case(null){
          userClaimableHash.put(Principal.toText(message.caller),game_.reward);
        }
      };
      game_.winner := message.caller;
      game_.time_ended := now();
      startNewGame();
      return #win;
    };
    //return if lost and detect if win extra roll
    if(extraRoll_){
      
      game_.reward += (ticketPrice/10)*4;
      game_.bonus += (ticketPrice/10)*1;
      if(game_.totalBet < 10){
        let userBonus_ = bonusPoolbyWallet.get(Principal.toText(message.caller));
        switch (userBonus_){
          case(?r){
            bonusPoolbyWallet.put(Principal.toText(message.caller),Array.append<Nat>(r, [game_.id]));
          };
          case(null){
            bonusPoolbyWallet.put(Principal.toText(message.caller),[game_.id]);
          }
        };

      };
      if(dice_1_==dice_2_){
        userDoubleRollQuantityHash.put(Principal.toText(message.caller), doubleRollRemaining_ +1);
        return #extra([dice_1_,dice_2_]);
      };
    };
    #lose([dice_1_,dice_2_]);
    
  } ;

  func log_history(){

  };

  public shared(message) func claimReward(g_ : Nat) : async Bool {
    let reward_ = userClaimableHash.get(Principal.toText(message.caller));
    switch (reward_){
        case(?r){
          let transferResult_ = await transfer(r,message.caller);
          switch transferResult_ {
            case (#success(x)) { 
              userClaimableHash.put(Principal.toText(message.caller),0);
              let claimHistory_ : T.ClaimHistory = {time = now(); icp_transfer_index=x; reward_claimed=r};
              let claimArray_ = userClaimHistoryHash.get(Principal.toText(message.caller));
              switch (claimArray_){
                case(?c){
                  userClaimHistoryHash.put(Principal.toText(message.caller),Array.append<T.ClaimHistory>(c, [claimHistory_]));
                };
                case(null){
                  userClaimHistoryHash.put(Principal.toText(message.caller), [claimHistory_]);
                }
              };
              return true; 
            };
            case (#error(txt)) {
              Debug.print("error "#txt );
              return false;
            }
          };
        };
        case(null){
          return false;
        }
      };
    false;
  };

  public shared(message) func claimBonusPool(g_ : Nat) : async Bool {
    //
    let gameArray_ = bonusPoolbyWallet.get(Principal.toText(message.caller));
    switch (gameArray_){
        case(?r){
          let val_ = Array.find<Nat>(r, func x = x == g_);
          if(val_ != null){
            let game_ = games.get(g_);
            game_.bonus_claimed := true;
            let transferResult_ = await transfer(game_.bonus,message.caller);
            switch transferResult_ {
              case (#success(x)) { 
                userClaimableHash.put(Principal.toText(message.caller),0);
                
                game_.bonus_winner := message.caller;
                let claimHistory_ : T.ClaimHistory = {time = now(); icp_transfer_index=x; reward_claimed=game_.bonus};
                let claimArray_ = userClaimHistoryHash.get(Principal.toText(message.caller));
                switch (claimArray_){
                  case(?c){
                    userClaimHistoryHash.put(Principal.toText(message.caller),Array.append<T.ClaimHistory>(c, [claimHistory_]));
                  };
                  case(null){
                    userClaimHistoryHash.put(Principal.toText(message.caller), [claimHistory_]);
                  }
                };
                return true; 
              };
              case (#error(txt)) {
                Debug.print("error "#txt );
                game_.bonus_claimed := false;
                return false;
              }
            };
            };
          
        };
        case(null){
          return false;
        }
      };
    false;
  };

  /*func transferEyesToken(to_ : Principal,quantity_ : Nat) : async T.TransferResult {

    let transferResult = await Eyes.icrc1_transfer({
      amount = eyesTokenDistribution * quantity_;
      fee = null;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=to_; subaccount=null};
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
        return #success(number);
      };
      case (#Err(msg)) {

        Debug.print("transfer error  ");
        switch (msg){
          case (#BadFee(number)){
            Debug.print("Bad Fee");
            return #error("Bad Fee");
          };
          case (#GenericError(number)){
            Debug.print("err "#number.message);
            return #error("Generic");
          };
          case (#InsufficientFunds(number)){
            Debug.print("insufficient funds");
            return #error("insufficient funds");
            
          };
          case _ {
            Debug.print("err");
          }
        };
        return #error("Other");
        };
    };
  }; */

  func transfer(amount_ : Nat, to_ : Principal) : async T.TransferResult {

    let transferResult = await ICPLedger.icrc1_transfer({
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=to_; subaccount=null};
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
        return #success(number);
      };
      case (#Err(msg)) {

        Debug.print("ICP transfer error  ");
        switch (msg){
          case (#BadFee(number)){
            Debug.print("Bad Fee");
            return #error("Bad Fee");
          };
          case (#GenericError(number)){
            Debug.print("err "#number.message);
            return #error("Generic");
          };
          case (#InsufficientFunds(number)){
            Debug.print("insufficient funds");
            return #error("insufficient funds");
            
          };
          case _ {
            Debug.print("ICP error err");
          }
        };
        return #error("ICP error Other");
        };
    };
  };

  func transferFrom(owner_ : Principal, amount_ : Nat) : async T.TransferResult {
    Debug.print("transferring from "#Principal.toText(owner_)#" by "#Principal.toText(Principal.fromActor(this))#" "#Nat.toText(amount_));
    let transferResult = await ICPLedger.icrc2_transfer_from({
      from = {owner=owner_; subaccount=null};
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=Principal.fromActor(this); subaccount=null};
      spender_subaccount=null;
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
         return #success(number);
      };
      case (#Err(msg)) {

        Debug.print("transfer error  ");
        switch (msg){
          case (#BadFee(number)){
            return #error("Bad Fee");
          };
          case (#GenericError(number)){
            return #error("Generic");
          };
          case (#BadBurn(number)){
            return #error("BadBurn");
          };
          case (#InsufficientFunds(number)){
            return #error("Insufficient Funds");
          };
          case (#InsufficientAllowance(number)){
            return #error("Insufficient Allowance ");
          };
          case _ {
            Debug.print("ICP err");
          }
        };
        return #error("ICP transfer other error");
        };
    };
  };

  

};