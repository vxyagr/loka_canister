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
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Char "mo:base/Char";
import { now } = "mo:base/Time";
import { abs } = "mo:base/Int";
import HashMap "mo:base/HashMap";
import { setTimer; cancelTimer; recurringTimer } = "mo:base/Timer";

import T "types";
//import Minter "canister:ckbtc_minter";
import CKBTC "canister:ckbtc_prod"; //PROD
//import Minter "ic:mqygn-kiaaa-aaaar-qaadq-cai";
//import CKBTC "canister:lbtc"; //DEV
//import LBTC "canister:lbtc";

shared ({ caller = owner }) actor class Miner({
  admin : Principal;
}) = this {
  //indexes
  //private stable var jwalletVault = "rg2ah-xl6x4-z6svw-bdxfv-klmal-cwfel-cfgzg-eoi6q-nszv5-7z5hg-sqe"; //DEV
  private stable var jwalletVault = "43hyn-pv646-27kl3-hhrll-wbdtc-k4idi-7mbyz-uvwxj-hgktq-topls-rae"; //PROD
  private var siteAdmin : Principal = admin;

  private stable var totalBalance = 0;
  private stable var totalWithdrawn = 0;

  //vautls
  private stable var defiCKBTCVault : Principal = admin;
  stable var lokaCKBTCVault : Principal = admin;
  private stable var minerCKBTCVault : Principal = admin;
  //stables
  private stable var minersIndex = 0;
  private stable var usersIndex = 0;
  private stable var transactionIndex = 0;
  private stable var pause = false : Bool;
  private stable var totalHashrate = 0;
  stable var lastF2poolCheck : Int = 0;
  private stable var distributionIndex = 0;

  private stable var timeStarted = false;
  stable var distributionHistoryList : [{ time : Int; data : Text }] = [];

  //buffers and hashmaps
  var minerStatus = Buffer.Buffer<T.MinerStatus>(0);
  var miners = Buffer.Buffer<T.Miner>(0);
  var transactions = Buffer.Buffer<T.TransactionHistory>(0);
  private var minerHash = HashMap.HashMap<Text, T.Miner>(0, Text.equal, Text.hash);
  private var jwalletId = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
  private var minerStatusAndRewardHash = HashMap.HashMap<Text, T.MinerStatus>(0, Text.equal, Text.hash);
  private var usernameHash = HashMap.HashMap<Text, Nat>(0, Text.equal, Text.hash);
  private var revenueHash = HashMap.HashMap<Text, [T.DistributionHistory]>(0, Text.equal, Text.hash);
  private var distributionHistoryByTimeStamp = HashMap.HashMap<Text, T.Distribution>(0, Text.equal, Text.hash);
  private var distributionTimestampById = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
  private var stakingHash

  //keys
  stable var f2poolKey : Text = "gxq33xia5tdocncubl0ivy91aetpiqm514wm6z77emrruwlg0l1d7lnrvctr4f5h";
  private var dappsKey = "0xSet";

  //upgrade temp params
  stable var minerStatus_ : [T.MinerStatus] = []; // for upgrade
  stable var miners_ : [T.Miner] = []; // for upgrade
  stable var transactions_ : [T.TransactionHistory] = [];
  stable var minerHash_ : [(Text, T.Miner)] = [];
  stable var minerStatusAndRewardHash_ : [(Text, T.MinerStatus)] = [];
  stable var usernameHash_ : [(Text, Nat)] = [];
  stable var distributionHistoryByTimeStamp_ : [(Text, T.Distribution)] = [];
  stable var distributionTimestampById_ : [(Text, Text)] = [];
  stable var revenueHash_ : [(Text, [T.DistributionHistory])] = [];
  stable var jwalletId_ : [(Text, Text)] = [];
  stable var schedulerId = 0;
  stable var nextTimeStamp = 0;
  stable var schedulerSecondsInterval = 10;
  stable var counter = 0;

  system func preupgrade() {
    miners_ := Buffer.toArray<T.Miner>(miners);
    minerStatus_ := Buffer.toArray<T.MinerStatus>(minerStatus);
    transactions_ := Buffer.toArray<T.TransactionHistory>(transactions);

    minerHash_ := Iter.toArray(minerHash.entries());
    usernameHash_ := Iter.toArray(usernameHash.entries());
    revenueHash_ := Iter.toArray(revenueHash.entries());

    minerStatusAndRewardHash_ := Iter.toArray(minerStatusAndRewardHash.entries());
    jwalletId_ := Iter.toArray(jwalletId.entries());

    distributionHistoryByTimeStamp_ := Iter.toArray(distributionHistoryByTimeStamp.entries());
    distributionTimestampById_ := Iter.toArray(distributionTimestampById.entries());
  };
  system func postupgrade() {
    miners := Buffer.fromArray<T.Miner>(miners_);
    minerStatus := Buffer.fromArray<(T.MinerStatus)>(minerStatus_);
    transactions := Buffer.fromArray<T.TransactionHistory>(transactions_);

    minerHash := HashMap.fromIter<Text, T.Miner>(minerHash_.vals(), 1, Text.equal, Text.hash);
    usernameHash := HashMap.fromIter<Text, Nat>(usernameHash_.vals(), 1, Text.equal, Text.hash);
    revenueHash := HashMap.fromIter<Text, [T.DistributionHistory]>(revenueHash_.vals(), 1, Text.equal, Text.hash);

    minerStatusAndRewardHash := HashMap.fromIter<Text, T.MinerStatus>(minerStatusAndRewardHash_.vals(), 1, Text.equal, Text.hash);
    jwalletId := HashMap.fromIter<Text, Text>(jwalletId_.vals(), 1, Text.equal, Text.hash);

    distributionHistoryByTimeStamp := HashMap.fromIter<Text, T.Distribution>(distributionHistoryByTimeStamp_.vals(), 1, Text.equal, Text.hash);
    distributionTimestampById := HashMap.fromIter<Text, Text>(distributionTimestampById_.vals(), 1, Text.equal, Text.hash);

    //let sched = await initScheduler();
  };

  public shared (message) func getCurrentScheduler() : async Nat {
    return schedulerId;
  };

  public shared (message) func getICPTimeString() : async Text {
    Debug.print("getting next timestamp");

    let tmn_ = now() / 1000000;
    let url = "https://api.lokamining.com/timeFromStamp?timestamp=" #Int.toText(tmn_);

    let decoded_text = await send_http(url);
    Debug.print(decoded_text);
    return decoded_text;
  };

  public shared (message) func getNext() : async Nat {
    assert (_isAdmin(message.caller));
    Debug.print("getting next timestamp");
    let tmn_ = now() / 1000000;
    let url = "https://api.lokamining.com/nextTimeStamp?timestamp=" #Int.toText(tmn_);

    let decoded_text = await send_http(url);
    Debug.print(decoded_text);
    return textToNat(decoded_text);
    //return 0;

  };

  public shared (message) func compareNow() : async Bool {
    assert (_isAdmin(message.caller));
    Debug.print("getting next timestamp");
    let tmn_ = now() / 1000000;
    let url = "https://api.lokamining.com/nextTimeStamp?timestamp=" #Int.toText(tmn_);

    let decoded_text = await send_http(url);
    Debug.print(decoded_text);
    return tmn_ > textToNat(decoded_text);
    //return 0;

  };

  public shared (message) func getStamp() : async Int {
    assert (_isAdmin(message.caller));
    Debug.print("getting next timestamp");
    let tmn_ = now() / 1000000;

    return tmn_;
    //return 0;

  };

  public query (message) func initialDistributionHour() : async Nat {
    return nextTimeStamp;
  };
  //function to check scheduler / scheduler
  //returns counter+10 each 10 seconds when waiting for night time, and only adds +1 when already active
  public query (message) func getCounter() : async Nat {
    return counter;
  };

  /*public shared (message) func getTimeStamp(tm_ : Int) : async Nat {
    Debug.print("getting next timestamp");
    let nn = tm_ / 1000000;
    //return Int.toText(nn);
    let url = "https://api.lokamining.com/nextTimeStamp?timestamp=" #Int.toText(nn);

    let decoded_text = await send_http(url);
    Debug.print(decoded_text);
    //return "";
    return textToNat(decoded_text);
    //return url;

  }; */

  public shared (message) func stopScheduler(id_ : Nat) : async Bool {
    assert (_isAdmin(message.caller));
    let res = cancelTimer(id_);
    true;
  };

  /*public shared (message) func forceEx() : async () {
    nextTimeStamp := 1;
  }; */

  public shared (message) func startScheduler() : async Nat {
    assert (_isAdmin(message.caller));
    let t_ = now() / 1000000;
    await initScheduler(t_);
  };

  private stable var distributionStatus : Text = "none";

  func initScheduler(t_ : Int) : async Nat {

    cancelTimer(schedulerId);
    let currentTimeStamp_ = t_;
    counter := 0;
    nextTimeStamp := 0;
    nextTimeStamp := await getNextTimeStamp(currentTimeStamp_);
    Debug.print("stamp " #Int.toText(nextTimeStamp));
    if (nextTimeStamp == 0) return 0;
    schedulerId := recurringTimer(
      #seconds(10),
      func() : async () {
        if (counter < 100) { counter += 10 } else { counter := 0 };
        let time_ = now() / 1000000;
        if (time_ >= nextTimeStamp) {
          counter := 200;
          if (distributionStatus == "none") {
            let res = await routine24();
            //schedulerSecondsInterval := 24 * 60 * 60;
            if (distributionStatus == "done") {
              nextTimeStamp := nextTimeStamp + (24 * 60 * 60 * 1000);
              distributionStatus := "none";
            };
          };
          //cancelTimer(schedulerId);
          // schedulerId := scheduler();

        };
      },
    );
    schedulerId;
  };

  func scheduler() : Nat {
    schedulerId := recurringTimer(
      // #seconds(24 * 60 * 60),
      #seconds(24 * 60 * 60),
      func() : async () {
        if (counter < 300) { counter += 1 } else { counter := 0 };
        let res = await routine24();
      },
    );
    schedulerId;
  };

  func getNextTimeStamp(tm_ : Int) : async Nat {
    Debug.print("getting next timestamp");
    let tmn_ = tm_;
    let url = "https://api.lokamining.com/nextTimeStamp?timestamp=" #Int.toText(tmn_);

    let decoded_text = await send_http(url);
    Debug.print(decoded_text);
    return textToNat(decoded_text);
    //return 0;

  };

  public shared (message) func clearData() : async () {
    assert (_isAdmin(message.caller));

  };

  func _isAdmin(p : Principal) : Bool {
    return (p == siteAdmin);
  };

  func _isApp(key : Text) : Bool {
    return (key == dappsKey);
  };

  func _isNotPaused() : Bool {
    if (pause) return false;
    true;
  };

  public query func isNotPaused() : async Bool {
    if (pause) return false;
    true;
  };

  public shared (message) func setCKBTCVault(vault_ : Principal) : async Principal {
    assert (_isAdmin(message.caller));
    lokaCKBTCVault := vault_;
    vault_;
  };

  public shared (message) func setJwalletVault(vault_ : Text) : async Text {
    assert (_isAdmin(message.caller));
    jwalletVault := vault_;
    vault_;
  };

  public query (message) func getCurrentIndex() : async Nat {
    usersIndex;
  };

  public shared (message) func pauseCanister(pause_ : Bool) : async Bool {
    assert (_isAdmin(message.caller));
    pause := pause_;
    pause_;
  };
  func _isNotRegistered(p : Principal, username_ : Text) : Bool {
    let miner_ = minerHash.get(Principal.toText(p));
    switch (miner_) {
      case (?m) {
        return false;
      };
      case (null) {
        return true;
      };
    };

  };

  func _isVerified(p : Principal, username_ : Text) : Bool {
    switch (minerHash.get(Principal.toText(p))) {
      case (?x) {
        let stats_ = minerStatus.get(x.id);
        // if(stats_.ve)
        return stats_.verified;
      };
      case (null) { return false };
    };
    if (_isNotRegistered(p, username_)) return false;

    let res_ = getMiner(p);
    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        let minerStatus_ = minerStatus.get(m.id);
        //if(m.)
        return minerStatus_.verified;
      };
    };

  };

  func _isUsernameVerified(username_ : Text) : Bool {

    switch (usernameHash.get(username_)) {
      case (?x) {
        let stats_ = minerStatus.get(x);
        // if(stats_.ve)
        return stats_.verified;
      };
      case (null) { return false };
    };

  };

  func _isAddressVerified(p : Principal) : Bool {

    //let miner_ = getMiner(p);
    let res_ = getMiner(p);
    switch (res_) {
      case (#none) {
        return false;
      };
      case (#ok(m)) {
        let minerStatus_ = minerStatus.get(m.id);
        //if(m.)
        return minerStatus_.verified;
      };
    };
  };

  func _isRegistered(p : Principal, username_ : Text) : Bool {
    let miner_ = minerHash.get(Principal.toText(p));
    switch (miner_) {
      case (?m) {
        return true;
      };
      case (null) {
        return false;
      };
    };
  };

  func _isNotVerified(p : Principal, username_ : Text) : Bool {
    if (_isVerified(p, username_)) return false;
    true;
  };

  public shared (message) func setDappsKey(key : Text) : async Text {
    assert (_isAdmin(message.caller));
    dappsKey := key;
    key;
  };

  private func addMiner(f2poolUsername_ : Text, hashrate_ : Nat, wallet : Principal) : async Bool {
    //assert(_isAdmin(message.caller));
    assert (_isNotRegistered(wallet, f2poolUsername_));
    assert (_isNotPaused());
    let miner_ = getMiner(wallet);
    let hash_ = hashrate_ * 1000000000000;
    if (_isNotRegistered(wallet, f2poolUsername_)) {
      let miner_ : T.Miner = {

        id = minersIndex;
        walletAddress = wallet;
        var username = f2poolUsername_;
        hashrate = hash_;
      };
      minerHash.put(Principal.toText(wallet), miner_);
      usernameHash.put(f2poolUsername_, minersIndex);
      miners.add(miner_);
      Debug.print("miner added");
      logMiner(minersIndex, f2poolUsername_, Nat.toText(hashrate_), Principal.toText(wallet));
      let minerStatus_ : T.MinerStatus = {
        id = minersIndex;
        var verified = true;
        var balance = 0;
        var totalWithdrawn = 0;
        var walletAddress = [];
        var bankAddress = [];
        var transactions = [];
      };
      minerStatusAndRewardHash.put(Nat.toText(minersIndex), minerStatus_);
      minerStatus.add(minerStatus_);
      minersIndex += 1;
      totalHashrate += hash_;
      true;
    } else {
      //update mining Pool
      false;
    };

  };

  public shared (message) func getCKBTCBalance() : async Nat {
    var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromActor(this); subaccount = null }));
    ckBTCBalance;
  };

  public shared (message) func updateckBTCBalance() : async () {
    let Minter = actor ("mqygn-kiaaa-aaaar-qaadq-cai") : actor {
      update_balance : ({ subaccount : ?Nat }) -> async {
        #Ok : [UtxoStatus];
        #Err : UpdateBalanceError;
      };
    };
    let result = await Minter.update_balance({ subaccount = null }); //"(record {subaccount=null;})"

  };

  //public shared(message) func getCKBTCMintAddress() : async Text {
  // var ckBTCBalance : Nat= (await CKBTC.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null}));
  //ckBTCBalance;
  //};

  public shared (message) func sendCKBTC(wallet_ : Text, subAccount : Text, amount_ : Nat) : async Bool {
    let wallet : Principal = Principal.fromText(wallet_);
    assert (_isAdmin(message.caller));
    var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromActor(this); subaccount = null }));
    //assert(ckBTCBalance>12);
    ckBTCBalance -= 12;

    let transferResult = await CKBTC.icrc1_transfer({
      amount = amount_;
      fee = ?10;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = wallet; subaccount = null };
      memo = null;
    });
    var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {
        return true;
      };
      case (#Err(msg)) { res := 0 };
    };
    true;
  };

  func btcToSats(btc : Float) : Int {
    let sats = 100000000 * btc;
    Float.toInt(sats);
  };

  func textToNat(txt : Text) : Nat {
    assert (txt.size() > 0);
    let chars = txt.chars();

    var num : Nat = 0;
    for (v in chars) {
      let charToNum = Nat32.toNat(Char.toNat32(v) -48);
      assert (charToNum >= 0 and charToNum <= 9);
      num := num * 10 + charToNum;
    };

    num;
  };

  public shared (message) func getJwalletId(type_ : Text, acc_ : Text) : async {
    #uuid : Text;
    #none : Text;
  } {
    if (_isAdmin(message.caller) == false) assert (_isAddressVerified(message.caller));
    switch (jwalletId.get(type_ #acc_)) {
      case (?j) {
        return #uuid(j);
      };
      case (null) {
        return #none("Account not found");
      };
    };
    return #none("Account not found");
  };

  public shared (message) func recordJwalletId(type_ : Text, acc_ : Text, uuid_ : Text) : async {
    #exist : Text;
    #ok;
  } {
    if (_isAdmin(message.caller) == false) assert (_isAddressVerified(message.caller));
    switch (jwalletId.get(type_ #acc_)) {
      case (?j) {

        return #exist(j);
      };
      case (null) {
        jwalletId.put(type_ #acc_, uuid_);
        return #ok;
      };
    };
    //return #ok("yo");
  };

  public shared (message) func getCKBTCMinter() : async Text {
    let Minter = actor ("mqygn-kiaaa-aaaar-qaadq-cai") : actor {
      get_btc_address : ({ subaccount : ?Nat }) -> async Text;
    };
    let result = await Minter.get_btc_address({ subaccount = null }); //"(record {subaccount=null;})"
    result;
  };

  func logTransaction(id_ : Nat, action_ : Text, amount_ : Text, txid_ : Text, currency_ : Text) {
    Debug.print("logging transaction " #action_);
    let transaction : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = action_;
      amount = amount_;
      txid = txid_;
      currency = currency_;
      //provider = provider_;
      //receiver = receiver_;
    };

    let array_ : [T.TransactionHistory] = [transaction];
    let status_ = minerStatus.get(id_);
    Debug.print("appending");
    status_.transactions := Array.append<T.TransactionHistory>(status_.transactions, array_);

    transactions.add(transaction);
    transactionIndex += 1;
  };

  func logDistribution(id_ : Nat, action_ : Text, amount_ : Text, txid_ : Text, currency_ : Text) {
    Debug.print("logging distribution " #action_);
    let transaction : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = action_;
      amount = amount_;
      txid = txid_;
      currency = currency_;
      //provider = provider_;
      //receiver = receiver_;
    };

    Debug.print("appending");

    transactions.add(transaction);
    transactionIndex += 1;
  };

  func logMiner(id_ : Nat, username_ : Text, hash_ : Text, wallet_ : Text) {
    let transaction : T.TransactionHistory = {
      id = transactionIndex;
      //caller = caller_;
      time = now();
      action = "new miner";
      receiver = "";
      amount = hash_;
      txid = username_;
      currency = "";
      provider = "";
    };

    transactions.add(transaction);
    transactionIndex += 1;
  };

  func send_http(url_ : Text) : async Text {
    let ic : T.IC = actor ("aaaaa-aa");

    let url = url_;

    let request_headers = [
      { name = "User-Agent"; value = "miner_canister" },
      { name = "Content-Type"; value = "application/json" },
      { name = "x-api-key"; value = "2021LokaInfinity" },
      { name = "F2P-API-SECRET"; value = f2poolKey },
    ];
    Debug.print("accessing " #url);
    let transform_context : T.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : T.HttpRequestArgs = {
      url = url;
      max_response_bytes = null; //optional for request
      headers = request_headers;
      body = null; //optional for request
      method = #get;
      transform = ?transform_context;
    };

    Cycles.add(30_000_000_000);

    let http_response : T.HttpResponsePayload = await ic.http_request(http_request);
    let response_body : Blob = Blob.fromArray(http_response.body);
    let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
      case (null) { "No value returned" };
      case (?y) { y };
    };
    decoded_text;
  };

  private func natToFloat(nat_ : Nat) : Float {
    let toNat64_ = Nat64.fromNat(nat_);
    let toInt64_ = Int64.fromNat64(toNat64_);
    let amountFloat_ = Float.fromInt64(toInt64_);
    return amountFloat_;
  };

  func getMiner(wallet_ : Principal) : { #none; #ok : T.Miner } {
    var miner_id : Nat = 0;
    let emptyMiner = {
      id = 0;
      walletAddress = siteAdmin;
      var username = "<empty>";
      hashrate = 0;
    };
    let miner_ = minerHash.get(Principal.toText(wallet_));
    switch (miner_) {
      case (?m) {
        return #ok(m);
      };
      case (null) {
        return #none;
      };
    };
  };

  public query (message) func getUserData() : async {
    #none : Nat;
    #ok : T.MinerData;
  } {

    assert (_isAddressVerified(message.caller));
    //let miner_ = getMiner(message.caller);
    let res_ = getMiner(message.caller);
    var id_ = 0;
    var revenueHistory_ : [T.DistributionHistory] = [];
    var yesterdayRevenue_ = 0;
    switch (res_) {
      case (#none) {
        return #none(1);
      };
      case (#ok(m)) {
        id_ := m.id;
        let status_ = minerStatus.get(id_);
        switch (revenueHash.get(Principal.toText(m.walletAddress))) {
          case (?r) {
            revenueHistory_ := r;
            if (Array.size(r) > 0) yesterdayRevenue_ := r[Array.size(r) -1].sats;
          };
          case (null) {

          };
        };

        let minerData : T.MinerData = {
          id = id_;
          walletAddress = m.walletAddress;
          walletAddressText = Principal.toText(m.walletAddress);
          username = m.username;
          hashrate = m.hashrate;
          verified = status_.verified;
          balance = status_.balance;
          //balance = 100000000;
          totalWithdrawn = status_.totalWithdrawn;

          savedWalletAddress = status_.walletAddress;
          bankAddress = status_.bankAddress;
          transactions = status_.transactions;
          revenueHistory = revenueHistory_;
          yesterdayRevenue = yesterdayRevenue_;
        };
        //Debug.print("fetched 3");
        return #ok(minerData);
      };
    };

  };

  public query (message) func fetchUserByPrincipal(p : Principal) : async {
    #none : Nat;
    #ok : T.MinerData;
  } {

    assert (_isAdmin(message.caller));
    let res_ = getMiner(p);
    var id_ = 0;
    var revenueHistory_ : [T.DistributionHistory] = [];
    var yesterdayRevenue_ = 0;
    switch (res_) {
      case (#none) {
        return #none(1);
      };
      case (#ok(m)) {
        id_ := m.id;
        let status_ = minerStatus.get(id_);
        switch (revenueHash.get(Principal.toText(m.walletAddress))) {
          case (?r) {
            revenueHistory_ := r;
            if (Array.size(r) > 0) yesterdayRevenue_ := r[Array.size(r) -1].sats;

          };
          case (null) {

          };
        };
        let minerData : T.MinerData = {
          id = id_;
          walletAddress = m.walletAddress;
          walletAddressText = Principal.toText(m.walletAddress);
          username = m.username;
          hashrate = m.hashrate;
          verified = status_.verified;
          balance = status_.balance;
          //balance = 100000000;
          totalWithdrawn = status_.totalWithdrawn;

          savedWalletAddress = status_.walletAddress;
          bankAddress = status_.bankAddress;
          transactions = status_.transactions;
          revenueHistory = revenueHistory_;
          yesterdayRevenue = yesterdayRevenue_;
        };
        //Debug.print("fetched 3");
        return #ok(minerData);
      };
    };

  };

  public query (message) func fetchUserById(p : Nat) : async T.MinerData {

    assert (_isAdmin(message.caller));
    let miner_ = miners.get(p);
    let status_ = minerStatus.get(miner_.id);
    var revenueHistory_ : [T.DistributionHistory] = [];
    var yesterdayRevenue_ = 0;
    switch (revenueHash.get(Principal.toText(miner_.walletAddress))) {
      case (?r) {
        revenueHistory_ := r;
        //let hist = Array.size(r);
        if (Array.size(r) > 0) yesterdayRevenue_ := r[Array.size(r) -1].sats;
      };
      case (null) {

      };
    };
    let minerData : T.MinerData = {
      id = miner_.id;
      walletAddress = miner_.walletAddress;
      walletAddressText = Principal.toText(miner_.walletAddress);
      username = miner_.username;
      hashrate = miner_.hashrate;
      verified = status_.verified;
      balance = status_.balance;
      //balance = 100000000;
      totalWithdrawn = status_.totalWithdrawn;

      savedWalletAddress = status_.walletAddress;
      bankAddress = status_.bankAddress;
      transactions = status_.transactions;
      revenueHistory = revenueHistory_;
      yesterdayRevenue = yesterdayRevenue_;
    };
    //Debug.print("fetched 3");
    minerData;
  };

  func textToFloat(t : Text) : Float {

    var i : Float = 1;
    var f : Float = 0;
    var isDecimal : Bool = false;

    for (c in t.chars()) {
      if (Char.isDigit(c)) {
        let charToNat : Nat64 = Nat64.fromNat(Nat32.toNat(Char.toNat32(c) -48));
        let natToFloat : Float = Float.fromInt64(Int64.fromNat64(charToNat));
        if (isDecimal) {
          let n : Float = natToFloat / Float.pow(10, i);
          f := f + n;
        } else {
          f := f * 10 + natToFloat;
        };
        i := i + 1;
      } else {
        if (Char.equal(c, '.') or Char.equal(c, ',')) {
          f := f / Float.pow(10, i); // Force decimal
          f := f * Float.pow(10, i); // Correction
          isDecimal := true;
          i := 1;
        } else {
          //throw Error.reject("NaN");
          return 0.0;
        };
      };
    };

    return f;
  };

  //@DEV- CORE FUNCTIONS TO CALCULATE 24 HOUR HASHRATE REWARD AND DISTRIBUTE IT PROPORTIONALLLY TO ALL MINERS
  // public shared(message) func routine24() : async Text {
  //"https://btc.lokamining.com:8443/v1/transaction/earnings"
  private func routine24() : async Text {
    distributionStatus := "processing";
    //assert(_isAdmin(message.caller));
    let now_ = now();
    let seconds_ = abs(now_ / 1000000000) -abs(lastF2poolCheck / 1000000000);
    let daySeconds_ = 3600 * 24;
    //if(seconds_ < daySeconds_){return "false";};
    // assert(_isAdmin(message.caller));
    let url = "https://api.lokamining.com/calculatef2poolRewardV2";
    let LokaMiner = actor ("rfrec-ciaaa-aaaam-ab4zq-cai") : actor {
      getCalculatedReward : (a : Text) -> async Text;
    };
    var hashrateRewards = "";
    var count_ = 0;

    try {
      let result = await LokaMiner.getCalculatedReward(url); //"(record {subaccount=null;})"
      hashrateRewards := result;
      distributionStatus := "done";
      //return result;
    } catch e {
      distributionStatus := "none";
      //return "reject";
    };

    logDistribution(0, "Distribute", hashrateRewards, "", "");

    //let hashrateRewards = "rantai1-lokabtc/1361772;rantai2-lokabtc/1356752;";

    Debug.print(hashrateRewards);
    // return hashrateRewards;
    distributeMiningRewards(hashrateRewards);
    let tm = now() / 1000000;
    let d = [{ time = tm; data = hashrateRewards }];
    distributionHistoryList := Array.append<{ time : Int; data : Text }>(distributionHistoryList, d);
    lastF2poolCheck := now_;
    hashrateRewards;
  };

  public shared (message) func routine24Force() : async Text {
    assert (_isAdmin(message.caller));
    let now_ = now();
    let seconds_ = abs(now_ / 1000000000) -abs(lastF2poolCheck / 1000000000);
    let daySeconds_ = 3600 * 24;
    //if(seconds_ < daySeconds_){return "false";};
    // assert(_isAdmin(message.caller));
    let url = "https://api.lokamining.com/calculatef2poolRewardV2";
    let hashrateRewards = await send_http(url);
    //let hashrateRewards = "rantai1-lokabtc/1361772;rantai2-lokabtc/1356752;";

    Debug.print(hashrateRewards);
    // return hashrateRewards;
    distributeMiningRewards(hashrateRewards);
    let tm = now() / 1000000;
    let d = [{ time = tm; data = hashrateRewards }];
    distributionHistoryList := Array.append<{ time : Int; data : Text }>(distributionHistoryList, d);
    lastF2poolCheck := now_;
    hashrateRewards;
  };

  func textSplit(word_ : Text, delimiter_ : Char) : [Text] {
    let hasil = Text.split(word_, #char delimiter_);
    let wordsArray = Iter.toArray(hasil);
    return wordsArray;
    //Debug.print(wordsArray[0]);
  };

  func distributeMiningRewards(rewards_ : Text) {

    let distributionData = textSplit(rewards_, ':');
    let timestamp_ = distributionData[0];
    let totalHash_ = distributionData[2];
    let totalReward_ = distributionData[1];
    let hashrateRewards = textSplit(distributionData[3], '|');
    totalBalance += textToNat(totalReward_);
    let dist_ : T.Distribution = {
      id = distributionIndex;
      hashrate = totalHash_;
      sats = totalReward_;
      time = timestamp_;
      data = distributionData[3];

    };

    distributionHistoryByTimeStamp.put(timestamp_, dist_);
    distributionTimestampById.put(Nat.toText(distributionIndex), timestamp_);
    distributionIndex += 1;

    Buffer.iterate<T.Miner>(
      miners,
      func(miner) {
        let status_ = minerStatus.get(miner.id);

        let user_ = miner.username;

        let isValid = Text.contains(rewards_, #text user_);
        if (isValid) {
          for (hashrateRewards_ in hashrateRewards.vals()) {
            if (hashrateRewards_ != "") {
              Debug.print("split " #hashrateRewards_);
              let hr_ = textSplit(hashrateRewards_, '/');
              var username = hr_[0];
              var reward = textToNat(hr_[2]);
              var hashrate_ = textToNat(hr_[1]);
              Debug.print("miner username : " #username # " " #miner.username);
              if (username == miner.username # "") {
                Debug.print("distributing " #Nat.toText(reward));
                status_.balance += reward;
                totalBalance += reward;
                let rev : [T.DistributionHistory] = [{
                  time = now();
                  hashrate = hashrate_;
                  sats = reward;
                }];
                switch (revenueHash.get(Principal.toText(miner.walletAddress))) {
                  case (?r) {
                    revenueHash.put(Principal.toText(miner.walletAddress), Array.append<T.DistributionHistory>(r, rev));

                  };
                  case (null) {
                    revenueHash.put(Principal.toText(miner.walletAddress), rev);
                  };
                };
              };

            };
          };
        } else {
          //status_.verified := false;
        };
      },
    );
  };

  //@DEV- CORE MINER VERIFICATION

  public query func transform(raw : T.TransformArgs) : async T.CanisterHttpResponsePayload {
    let transformed : T.CanisterHttpResponsePayload = {
      status = raw.response.status;
      body = raw.response.body;
      headers = [
        {
          name = "Content-Security-Policy";
          value = "default-src 'self'";
        },
        { name = "Referrer-Policy"; value = "strict-origin" },
        { name = "Permissions-Policy"; value = "geolocation=(self)" },
        {
          name = "Strict-Transport-Security";
          value = "max-age=63072000";
        },
        { name = "X-Frame-Options"; value = "DENY" },
        { name = "X-Content-Type-Options"; value = "nosniff" },
      ];
    };
    transformed;

  };

  func generateUUID() : Text {
    "UUID-123456789";
  };

};
