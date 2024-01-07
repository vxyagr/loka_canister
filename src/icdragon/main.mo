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
import DRAGON "canister:dragon";
//import CKBTC "canister:ckbtc_ledger";
//import LBTC "canister:lbtc";

shared ({ caller = owner }) actor class Miner({
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
  private stable var ticketPrice = 5000000;
  private stable var dragonToken = false;
  private stable var dragonTokenDistribution = 100000000;
  private stable var dragonDays = 0;

  private var userTicketQuantityHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userTicketPurchaseHash = HashMap.HashMap<Text, [T.TicketPurchase]>(0, Text.equal, Text.hash);
  private var userClaimableHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var userClaimHistoryHash = HashMap.HashMap<Text, [T.ClaimHistory]>(0, Text.equal, Text.hash);
  private var userBetHistoryHash = HashMap.HashMap<Text, [T.Bet]>(0, Text.equal, Text.hash);

  //@dev--variables and history
  var games = Buffer.Buffer<T.Game>(0);
  var ticketPurchaseHistory = Buffer.Buffer<T.TicketPurchase>(0);
  var betHistory = Buffer.Buffer<T.Bet>(0);
  

  //upgrade temp params
  stable var games_ : [T.Game]= []; // for upgrade
  stable var ticketPurchaseHistory_ : [T.TicketPurchase]= []; // for upgrade 
  stable var betHistory_ : [T.Bet] = [];

  stable var userTicketQuantityHash_ : [(Text,Nat)] = []; 
  stable var userTicketPurchaseHash_ : [(Text,[T.TicketPurchase])] = []; 
  stable var userClaimableHash_ : [(Text, Nat)] = [];
  stable var userClaimHistoryHash_ : [(Text, [T.ClaimHistory])] = [];
  stable var userBetHistoryHash_ : [(Text,[T.Bet])]=[];
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
        userTicketPurchaseHash := HashMap.fromIter<Text, [T.TicketPurchase]>(userTicketPurchaseHash_.vals(), 1, Text.equal, Text.hash);
        userClaimableHash := HashMap.fromIter<Text, Nat>(userClaimableHash_.vals(), 1, Text.equal, Text.hash);
        userClaimHistoryHash := HashMap.fromIter<Text, [T.ClaimHistory]>(userClaimHistoryHash_.vals(), 1, Text.equal, Text.hash);
        userBetHistoryHash := HashMap.fromIter<Text, [T.Bet]>(userBetHistoryHash_.vals(), 1, Text.equal, Text.hash);
        
  };

  //@dev timers initialization
   var halving = ignore recurringTimer(#seconds (24*60*60*10),  func () : async () {
      if(dragonToken){
        dragonTokenDistribution := dragonTokenDistribution/2;
        dragonDays+=1;
        //if(dragonDays==30)dragonToken:=false;
      };
  });

 

  public shared(message) func clearData() : async (){
    assert(_isAdmin(message.caller));
    
    gameIndex :=0;
    transactionIndex :=0;
    firstGameStarted:=false;
    betIndex:=0;
    ticketIndex := 0;
    ticketPrice := 5_000_000;
    dragonToken := false;
    dragonTokenDistribution := 100_000_000_000;
    dragonDays := 0;


    games := Buffer.Buffer<T.Game>(0);
    ticketPurchaseHistory := Buffer.Buffer<T.TicketPurchase>(0);
    betHistory := Buffer.Buffer<T.Bet>(0);
    
    userTicketQuantityHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    userTicketPurchaseHash := HashMap.HashMap<Text, [T.TicketPurchase]>(0, Text.equal, Text.hash);
    userClaimableHash := HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
    userClaimHistoryHash := HashMap.HashMap<Text, [T.ClaimHistory]>(0, Text.equal, Text.hash);
    userBetHistoryHash := HashMap.HashMap<Text, [T.Bet]>(0, Text.equal, Text.hash);

    
    
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

  public shared(message) func setDragonToken(active_ : Bool) : async Bool {
    assert(_isAdmin(message.caller));
    dragonToken := active_;
    dragonToken;
  };

  public query(message) func getDevPool() : async Principal {
    devPool;
  };
   public shared(message) func setTicketPrice(price_ : Nat) : async Nat {
    assert(_isAdmin(message.caller));
    ticketPrice := price_ ;
    ticketPrice;
  };

  public query(message) func getCurrentIndex() : async Nat {
    gameIndex;
  };

  public query(message) func getUserData() : async Bool{
    //return user data
    true;
  };

  public query(message) func getCurrentGame() : async Bool{
    //return game data
    true;
  };

  public shared(message) func pauseCanister(pause_ : Bool) : async Bool {
    assert(_isAdmin(message.caller));
    pause :=pause_;
    pause_;
  } ;

  /*
buy_ticket
roll_dice
claim_reward
log_history
rebase_game
  */
  public shared(message) func book_ticket(quantity_ : Nat, ticketPrice : Nat, totalPrice_ : Nat) : async T.BookTicketResult {
    let ticketBook_ : T.TicketPurchase = {id=ticketIndex;walletAddress=?message.caller;time=now();quantity=quantity_;totalPrice=totalPrice_;var paid=false;};
    ticketPurchaseHistory.add(ticketBook_);
    let ticketBookNow_ = ticketPurchaseHistory.get(ticketIndex);
    ticketIndex+=1;
    //Pay
    let transferRes_ = await transferFrom(message.caller,totalPrice_);
    
    var transIndex_ = 0;
    switch transferRes_ {
      case (#success(x)) { transIndex_ := x; };
      case (#error(txt)) {
        Debug.print("error "#txt );
        return #transferFailed(txt);
      }
    };
    assert(transIndex_!=0);
    ticketBookNow_.paid:=true;
    let userTickets_ = userTicketPurchaseHash.get(Principal.toText(message.caller));
    switch (userTickets_) {
      case (?x) {
        userTicketPurchaseHash.put(Principal.toText(message.caller), Array.append<T.TicketPurchase>(x, [ticketBookNow_]));
      };
      case (null) {
        userTicketPurchaseHash.put(Principal.toText(message.caller), [ticketBookNow_]);
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

    //check if Token started, mint Eyes to address based on emission halving
    if(dragonToken){
      let res_ = transferDragonToken(message.caller);
    };
    
    #success(quantity_);
  } ;

 
  //@dev-- called to start game for the first time by admin
  public shared(message) func firstGame() : async  Bool {
    assert(_isAdmin(message.caller));
    assert(gameIndex==0);
    assert(firstGameStarted==false);
    Debug.print("Starting new game ");
    let newGame : T.Game = {id = gameIndex; var winner = siteAdmin; time_created = now(); var time_ended=0; var reward=0; var bets = []};
    games.add(newGame);
    firstGameStarted:=true;
    let allgame = games.size();
    true;
  };

  func startNewGame(){
    gameIndex +=1;
    let newGame : T.Game = {id = gameIndex; var winner = siteAdmin; time_created = now(); var time_ended=0; var reward=0; var bets = []};
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
    //get the game data
    let allgame = games.size();
    Debug.print("curent game "#Nat.toText(gameIndex)#" of "#Nat.toText(allgame));
    let game_ = games.get(game_id);
    let gameBets_ = game_.bets;
    var remaining_ : Nat= 0;
    Debug.print("check remaining");
    //get remaining dice roll ticket
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
    if (remaining_==0)return #noroll;
    

    //ICP send 50% of ticket price to holder
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
    //ROLL!
    //substract ticket
    userTicketQuantityHash.put(Principal.toText(message.caller), remaining_-1);
    let dice_1_ = await roll();
    let dice_2_ = await roll();
    Debug.print("result "#Nat8.toText(dice_1_)#" and "#Nat8.toText(dice_2_));
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
    //return if lost
    game_.reward += (ticketPrice/2);
    #lose([dice_1_,dice_2_]);
    
  } ;

  func log_history(){

  };

  func transferDragonToken(to_ : Principal) : async T.TransferResult {

    let transferResult = await DRAGON.icrc1_transfer({
      amount = dragonTokenDistribution;
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
  };

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
  };

  func transferFrom(owner_ : Principal, amount_ : Nat) : async T.TransferResult {
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
          case (#InsufficientFunds(number)){
            return #error("Insufficient Funds");
          };
          case _ {
            Debug.print("err");
          }
        };
        return #error("Other");
        };
    };
  };

};