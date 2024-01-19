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
//import CKBTC "canister:ckbtc_ledger"; //PROD
//import Minter "ic:mqygn-kiaaa-aaaar-qaadq-cai";
import CKBTC "canister:lbtc"; //DEV
//import LBTC "canister:lbtc";

shared ({ caller = owner }) actor class Miner({
  admin : Principal;
}) = this {
  //indexes
  private stable var jwalletVault = "rg2ah-xl6x4-z6svw-bdxfv-klmal-cwfel-cfgzg-eoi6q-nszv5-7z5hg-sqe"; //DEV
  //PROD!! private stable var jwalletVault = "43hyn-pv646-27kl3-hhrll-wbdtc-k4idi-7mbyz-uvwxj-hgktq-topls-rae"; //PROD
  private var siteAdmin : Principal = admin;

  private stable var totalBalance = 0;
  private stable var totalWithdrawn = 0;

  //vautls
  stable var lokaCKBTCVault : Principal = admin;
  private stable var minerCKBTCVault : Principal = admin;
  //stables
  private stable var minersIndex = 0;
  private stable var transactionIndex = 0;
  private stable var pause = false : Bool;
  private stable var totalHashrate = 0;
  stable var lastF2poolCheck : Int = 0;

  private stable var timeStarted = false;

  //buffers and hashmaps
  var minerStatus = Buffer.Buffer<T.MinerStatus>(0);
  var miners = Buffer.Buffer<T.Miner>(0);
  var transactions = Buffer.Buffer<T.TransactionHistory>(0);
  private var minerHash = HashMap.HashMap<Text, T.Miner>(0, Text.equal, Text.hash);
  private var minerStatusAndRewardHash = HashMap.HashMap<Text, T.MinerStatus>(0, Text.equal, Text.hash);
  //keys
  stable var f2poolKey : Text = "gxq33xia5tdocncubl0ivy91aetpiqm514wm6z77emrruwlg0l1d7lnrvctr4f5h";
  private var dappsKey = "0xSet";

  //upgrade temp params
  stable var minerStatus_ : [T.MinerStatus] = []; // for upgrade
  stable var miners_ : [T.Miner] = []; // for upgrade
  stable var transactions_ : [T.TransactionHistory] = [];
  stable var minerHash_ : [(Text, T.Miner)] = [];
  stable var minerStatusAndRewardHash_ : [(Text, T.MinerStatus)] = [];

  system func preupgrade() {
    miners_ := Buffer.toArray<T.Miner>(miners);
    minerStatus_ := Buffer.toArray<T.MinerStatus>(minerStatus);
    transactions_ := Buffer.toArray<T.TransactionHistory>(transactions);

    minerHash_ := Iter.toArray(minerHash.entries());
    minerStatusAndRewardHash_ := Iter.toArray(minerStatusAndRewardHash.entries());
  };
  system func postupgrade() {
    miners := Buffer.fromArray<T.Miner>(miners_);
    minerStatus := Buffer.fromArray<(T.MinerStatus)>(minerStatus_);
    transactions := Buffer.fromArray<T.TransactionHistory>(transactions_);

    minerHash := HashMap.fromIter<Text, T.Miner>(minerHash_.vals(), 1, Text.equal, Text.hash);
    minerStatusAndRewardHash := HashMap.fromIter<Text, T.MinerStatus>(minerStatusAndRewardHash_.vals(), 1, Text.equal, Text.hash);
  };

  public shared (message) func clearData() : async () {
    assert (_isAdmin(message.caller));
    minerStatus := Buffer.Buffer<T.MinerStatus>(0);
    miners := Buffer.Buffer<T.Miner>(0);
    transactions := Buffer.Buffer<T.TransactionHistory>(0);
    minerHash := HashMap.HashMap<Text, T.Miner>(0, Text.equal, Text.hash);
    minerStatusAndRewardHash := HashMap.HashMap<Text, T.MinerStatus>(0, Text.equal, Text.hash);

    totalBalance := 0;
    minersIndex := 0;
    totalWithdrawn := 0;
    lastF2poolCheck := 0;
    transactionIndex := 0;
    timeStarted := false;
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

  public shared (message) func setMinerCKBTCVault(vault_ : Principal) : async Principal {
    assert (_isAdmin(message.caller));
    minerCKBTCVault := vault_;
    vault_;
  };

  public query (message) func getCurrentIndex() : async Nat {
    minersIndex;
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
    if (_isNotRegistered(p, username_)) return false;

    let miner_ = getMiner(p);
    let minerStatus_ = minerStatus.get(miner_.id);
    minerStatus_.verified;
  };

  func _isAddressVerified(p : Principal) : Bool {

    let miner_ = getMiner(p);
    if (miner_.username == "<empty>") return false;
    let minerStatus_ = minerStatus.get(miner_.id);
    minerStatus_.verified;
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

  public query (message) func isVerified(p : Principal) : async Bool {
    let miner_ = getMiner(p);
    if (miner_.username == "<empty>") { return false };
    true;
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

  public shared (message) func setF2PoolKey(key : Text) : async Text {
    assert (_isAdmin(message.caller));
    f2poolKey := key;
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

  public shared (message) func toggleRoutine(b_ : Bool) : async Bool {
    timeStarted := b_;
    timeStarted;
  };

  public query (message) func getBalance() : async Nat {
    totalBalance;
  };

  public query (message) func getWithdrawn() : async Nat {
    totalBalance;
  };
  public shared (message) func getCKBTCBalance() : async Nat {
    var ckBTCBalance : Nat = (await CKBTC.icrc1_balance_of({ owner = Principal.fromActor(this); subaccount = null }));
    ckBTCBalance;
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

  public shared (message) func getCKBTCMinter() : async Text {
    let Minter = actor ("mqygn-kiaaa-aaaar-qaadq-cai") : actor {
      get_btc_address : ({ subaccount : ?Nat }) -> async Text;
    };
    let result = await Minter.get_btc_address({ subaccount = null }); //"(record {subaccount=null;})"
    result;
  };

  public shared (message) func withdrawIDR(quoteId_ : Text, amount_ : Nat, bankID_ : Text, memoParam_ : [Nat8]) : async Bool {
    assert (_isNotPaused());
    assert (_isAddressVerified(message.caller));
    // let addr = Principal.fromText(address);
    let amountNat_ : Nat = amount_;
    let miner_ = getMiner(message.caller);
    //let miner_ = miners_[0];
    var memo_ : Blob = Text.encodeUtf8(bankID_ # "." #quoteId_);
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id);
    assert (minerStatus_.balance > amount_);

    /*let transferResult = await CKBTC.icrc2_transfer_from({
      from = { owner = minerCKBTCVault; subaccount = null };
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = Principal.fromText(jwalletVault); subaccount = null };
      spender_subaccount = null;
      memo = null;
    }); */

    let transferResult = await CKBTC.icrc1_transfer({
      amount = amount_;
      fee = ?0;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = Principal.fromText(jwalletVault); subaccount = null };
      memo = ?memoParam_;
    });

    var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {

        logTransaction(miner_.id, "{\"action\":\"withdraw IDR\",\"receiver\":\"" #quoteId_ # "\"}", Nat.toText(amount_), Int.toText(number), "{\"currency\":\"IDR\",\"bank\":\"" #bankID_ # "\"}");
        totalBalance -= amount_;
        minerStatus_.balance -= amount_;
        minerStatus_.totalWithdrawn += amount_;
        totalWithdrawn += amount_;
        totalBalance -= amount_;
        // logTransaction(miner_.id, "withdraw IDR", Nat.toText(amount_), Int.toText(number) # " " #quoteId_, "IDR ");
        return true;
      };
      case (#Err(msg)) {

        Debug.print("transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            Debug.print("Bad Fee");
          };
          case (#GenericError(number)) {
            Debug.print("err " #number.message);
          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
            return false;
          };
          case _ {
            Debug.print("err");
          };
        };
        res := 0;
      };
    };

    false;

  };

  public shared (message) func withdrawCKBTC(username_ : Text, amount_ : Nat, address : Text) : async T.TransferRes {
    assert (_isNotPaused());
    assert (_isVerified(message.caller, username_));
    assert (totalBalance > amount_);
    //let addr = Principal.fromText(message.caller);
    let amountNat_ : Nat = amount_;
    let miner_ = getMiner(message.caller);
    //let miner_ = miners_[0];
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id);
    assert (minerStatus_.balance > amount_);

    let transferResult = await CKBTC.icrc1_transfer({
      amount = amount_;
      fee = ?0;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = Principal.fromText(address); subaccount = null };
      memo = null;
    });
    var res = 0;

    //var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {

        logTransaction(miner_.id, "{\"action\":\"withdraw CKBTC\",\"receiver\":\"" #address # "\"}", Nat.toText(amount_), Int.toText(number), "{\"currency\":\"CKBTC\",\"chain\":\"ICP\"}");
        minerStatus_.balance -= amount_;
        minerStatus_.totalWithdrawn += amount_;
        totalWithdrawn += amount_;
        totalBalance -= amount_;
        return #success(number);
      };
      case (#Err(msg)) {

        Debug.print("transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            let a = number.expected_fee;
            Debug.print("Bad Fee " #Nat.toText(a));
            return #error("Bad Fee " #Nat.toText(a));
          };
          case (#GenericError(number)) {
            Debug.print("err " #number.message);
            return #error("Generic Error");
          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
            return #error("Operator error");
          };
          case _ {
            Debug.print("err");
          };
        };
        res := 0;
      };
    };

    return #error("Other Error");
  };

  public query (message) func whoCall() : async Text {
    return Principal.toText(message.caller);
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

  public shared (message) func forcelogTransaction(id_ : Nat, action_ : Text, amount_ : Text, txid_ : Text, currency_ : Text) : async [T.TransactionHistory] {
    assert (_isAdmin(message.caller));
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
    let status_ = minerStatus_.get(id_);

    status_.transactions := Array.append<T.TransactionHistory>(status_.transactions, array_);

    transactions.add(transaction);
    transactionIndex += 1;
    status_.transactions;
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

  public shared (message) func withdrawUSDT(username_ : Text, amount_ : Nat, addr_ : Text, usd_ : Text) : async T.TransferRes {
    assert (_isNotPaused());
    assert (_isVerified(message.caller, username_));
    let amountNat_ : Nat = amount_;
    let miner_ = getMiner(message.caller);
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id);

    let ic : T.IC = actor ("aaaaa-aa");
    let uid_ = addr_ #usd_ #Int.toText(now());
    let url = "https://api.lokamining.com/transfer?targetAddress=" #addr_ # "&amount=" #usd_ # "&id=" #uid_;
    let decoded_text = await send_http(url);
    //let decoded_text = "transfersuccess";
    //return decoded_text;
    Debug.print("result " #decoded_text);
    var isValid = Text.contains(decoded_text, #text "transfersuccess");
    if (isValid) {
      let hashtext_ = textSplit(decoded_text, '/');
      let res = await moveCKBTC(amount_);
      if (res) {
        minerStatus_.totalWithdrawn += amount_;
        totalBalance -= amount_;
        totalWithdrawn += amount_;
      };
      logTransaction(miner_.id, "{\"action\":\"withdraw USDT\",\"receiver\":\"" #addr_ # "\"}", Nat.toText(amount_), decoded_text, "{\"currency\":\"USDT\",\"chain\":\"Arbitrum\"}");
      //logTransaction(miner_.id, "{action:\"withdrawCKBTC\",receiver:\""#address#"\"}", Nat.toText(amount_), Int.toText(number), "{currency:\"CKBTC\",chain:\"ICP\"}");

      return #success(1);

      //return true;
    };
    return #error(decoded_text);
    //decoded_text;
  };

  public shared (message) func testUSDT(success_ : Bool) : async Text {

    if (success_) return "USDT transferred";
    //logTransaction(miner_.id,"withdraw USDT", Nat.toText(amount_), hashtext_[1], "USDT");
    if (success_ == false) return "Failed";
    //return true;
    return "None";

  };

  public shared (message) func testCKBTC(success_ : Bool) : async Bool {

    return success_;
  };

  //@dev -- whenever USDT is withdrawn from Loka USDT pool, CKBTC will be sent as payment from Miner Pool to Loka CKBTC Pool
  func moveCKBTC(amount_ : Nat) : async Bool {
    assert (_isNotPaused());

    let amountNat_ : Nat = amount_;

    /*let transferResult = await CKBTC.icrc2_transfer_from({
      from = { owner = minerCKBTCVault; subaccount = null };
      amount = amount_;
      fee = null;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = lokaCKBTCVault; subaccount = null };
      spender_subaccount = null;
      memo = null;
    }); */

    let transferResult = await CKBTC.icrc1_transfer({
      amount = amount_;
      fee = ?0;
      created_at_time = null;
      from_subaccount = null;
      to = { owner = lokaCKBTCVault; subaccount = null };
      memo = null;
    });
    //var res = 0;
    var res = 0;
    switch (transferResult) {
      case (#Ok(number)) {
        return true;
      };
      case (#Err(msg)) {

        Debug.print("transfer error  ");
        switch (msg) {
          case (#BadFee(number)) {
            Debug.print("Bad Fee");
          };
          case (#GenericError(number)) {
            Debug.print("err " #number.message);
          };
          case (#InsufficientFunds(number)) {
            Debug.print("insufficient funds");
            return false;
          };
          case _ {
            Debug.print("err");
          };
        };
        res := 0;
      };
    };

    false;
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

  func getMiner(wallet_ : Principal) : T.Miner {
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
        return m;
      };
      case (null) {
        return emptyMiner;
      };
    };
  };

  /*public query (message) func getMinerP() : async Text {

    var miner_id : Nat = 0;
    let emptyMiner = {
      id = 0;
      walletAddress = siteAdmin;
      var username = "<empty>";
      hashrate = 0;
    };
    let miner_ = minerHash.get(Principal.toText(message.caller));
    switch (miner_) {
      case (?m) {
        return "miner found";
      };
      case (null) {
        "Null";
      };
    };
  }; */

  public query (message) func getMinerData() : async T.MinerData {

    assert (_isAddressVerified(message.caller));
    let miner_ = getMiner(message.caller);
    let status_ = minerStatus.get(miner_.id);

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
    };
    //Debug.print("fetched 3");
    minerData;
  };

  public query (message) func checkMiner(p_ : Text) : async T.MinerData {
    assert (_isAdmin(message.caller));
    let addr_ = Principal.fromText(p_);
    assert (_isAddressVerified(addr_));
    let miner_ = getMiner(addr_);
    let status_ = minerStatus.get(miner_.id);

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
    };
    //Debug.print("fetched 3");
    minerData;
  };

  public query (message) func getWallets(id_ : Nat) : async [T.WalletAddress] {

    let miner_ = minerStatus.get(id_);
    miner_.walletAddress;
  };

  public shared (message) func saveWalletAddress(name_ : Text, address_ : Text, currency_ : Text) : async Bool {
    assert (_isAddressVerified(message.caller));
    let miner_ = getMiner(message.caller);
    let status_ = minerStatus.get(miner_.id);
    let isthere = Array.find<T.WalletAddress>(status_.walletAddress, func wallet = wallet.address == address_);
    assert (isthere == null);
    let wallet_ : [T.WalletAddress] = [{
      name = name_;
      address = address_;
      currency = currency_;
    }];
    status_.walletAddress := Array.append<T.WalletAddress>(status_.walletAddress, wallet_);
    true;
  };

  public shared (message) func saveBankAddress(name_ : Text, account_ : Text, bankName_ : Text, jwalletId_ : Text) : async Bool {
    assert (_isAddressVerified(message.caller));
    let miner_ = getMiner(message.caller);
    let status_ = minerStatus.get(miner_.id);
    let isthere = Array.find<T.BankAddress>(status_.bankAddress, func bank = bank.accountNumber == account_);
    assert (isthere == null);
    let bank_ : [T.BankAddress] = [{
      name = name_;
      accountNumber = account_;
      bankName = bankName_;
      jwalletId = jwalletId_;
    }];
    status_.bankAddress := Array.append<T.BankAddress>(status_.bankAddress, bank_);
    true;
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

  public shared (message) func setBalance(b : Nat) : async Bool {
    let miner_ = getMiner(message.caller);
    let minerStatus_ = minerStatus.get(miner_.id);
    minerStatus_.balance := b;
    true;
  };

  //@DEV- CORE FUNCTIONS TO CALCULATE 24 HOUR HASHRATE REWARD AND DISTRIBUTE IT PROPORTIONALLLY TO ALL MINERS
  // public shared(message) func routine24() : async Text {
  private func routine24() : async Text {
    //assert(_isAdmin(message.caller));
    let now_ = now();
    let seconds_ = abs(now_ / 1000000000) -abs(lastF2poolCheck / 1000000000);
    let daySeconds_ = 3600 * 24;
    //if(seconds_ < daySeconds_){return "false";};
    // assert(_isAdmin(message.caller));
    let url = "https://api.lokamining.com/calculatef2poolReward";
    let hashrateRewards = await send_http(url);
    logDistribution(0, "Distribute", hashrateRewards, "", "");

    //let hashrateRewards = "rantai1-lokabtc/1361772;rantai2-lokabtc/1356752;";

    Debug.print(hashrateRewards);
    // return hashrateRewards;
    distributeMiningRewards(hashrateRewards);
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
    let url = "https://api.lokamining.com/calculatef2poolReward";
    let hashrateRewards = await send_http(url);
    //let hashrateRewards = "rantai1-lokabtc/1361772;rantai2-lokabtc/1356752;";

    Debug.print(hashrateRewards);
    // return hashrateRewards;
    distributeMiningRewards(hashrateRewards);
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

    let hashrateRewards = textSplit(rewards_, ';');
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
              var reward = textToNat(hr_[1]);
              Debug.print("miner username : " #username # " " #miner.username);
              if (username == miner.username # "-lokabtc") {
                Debug.print("distributing " #Nat.toText(reward));
                status_.balance += reward;
                totalBalance += reward;
              };
            };
          };
        } else {
          status_.verified := false;
        };
      },
    );
  };

  //@DEV- CORE MINER VERIFICATION
  public shared (message) func verifyMiner(uname : Text, hash_ : Nat) : async Bool {
    assert (_isNotRegistered(message.caller, uname));
    //assert (_isAddressVerified(message.caller) == false);
    let url = "https://api.f2pool.com/bitcoin/lokabtc/" #uname # "-lokabtc";

    let decoded_text = await send_http(url);

    let hashText = Nat.toText(hash_);
    var isValid = Text.contains(decoded_text, #text hashText);
    if (isValid) {
      let miner_ = addMiner(uname, hash_, message.caller);
    };
    isValid;

  };

  func removeMiner(p_ : Principal) : async Bool {
    assert (_isAddressVerified(p_));
    let miner_ = getMiner(p_);
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id);
    minerStatus_.verified := false;
    miner_.username := "";

    true;
  };

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

  var scheduler = ignore recurringTimer(
    #seconds(24 * 60 * 60),
    func() : async () {
      //var scheduler = ignore recurringTimer(#seconds (10),  func () : async () {
      Debug.print("running 2");
      let res = await routine24();
      if (timeStarted) {
        let res = await routine24();
      };
    },
  );

};
