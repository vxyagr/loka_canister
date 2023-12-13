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


import T "types";
import CKBTC "canister:ckbtc_ledger";

shared ({ caller = owner }) actor class Miner({
  admin: Principal
}) =this{
  //indexes
  private stable var minersIndex = 0;
  private stable var transactionIndex = 0;

  private stable var pause = false : Bool;
  private var totalConsumedHashrate = 0;
  private var siteAdmin : Principal = admin;
  private var dappsKey = "0xSet";
  private stable var totalHashrate = 0;
  private var totalBalance = 0;
  private var totalWithdrawn = 0;
  stable var lastF2poolCheck : Int = 0;
  var lokaCKBTCVault : Principal = admin; 



  var minerStatus = Buffer.Buffer<T.MinerStatus>(0);
  var miners = Buffer.Buffer<T.Miner>(0);
  //var minerRewards = Buffer.Buffer<T.MinerReward>(0);
  var transactions = Buffer.Buffer<T.TransactionHistory>(0);
  

  var f2poolKey : Text = "gxq33xia5tdocncubl0ivy91aetpiqm514wm6z77emrruwlg0l1d7lnrvctr4f5h";


  //upgrade temp params
  stable var minerStatus_ : [T.MinerStatus]= []; // for upgrade
  stable var miners_ : [T.Miner]= []; // for upgrade 
  //stable var minerRewards_ : [T.MinerReward]=[];

  system func preupgrade() {
        miners_ := Buffer.toArray<T.Miner>(miners);
        minerStatus_ := Buffer.toArray<T.MinerStatus>(minerStatus);
        //minerRewards_ := Buffer.toArray<T.MinerReward>(minerRewards);
     
  };
  system func postupgrade() {
        miners := Buffer.fromArray<T.Miner>(miners_); 
        minerStatus:= Buffer.fromArray<(T.MinerStatus)>(minerStatus_);
        //minerRewards := Buffer.fromArray<T.MinerReward>(minerRewards_);
  };

  public shared(message) func clearData() : async (){
    assert(_isAdmin(message.caller));
    minerStatus := Buffer.Buffer<T.MinerStatus>(0);
    miners := Buffer.Buffer<T.Miner>(0);
    //minerRewards := Buffer.Buffer<T.MinerReward>(0);
    totalBalance :=0;
    minersIndex := 0;
    totalWithdrawn :=0;
    lastF2poolCheck :=0;
    transactionIndex :=0;
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

  public shared(message) func setCKBTCVault(vault_ : Principal) : async Principal {
    assert(_isAdmin(message.caller));
    lokaCKBTCVault := vault_;
    vault_;
  };

  public query(message) func getIndex() : async Nat {
    minersIndex;
  };

  public shared(message) func pauseCanister(pause_ : Bool) : async Bool {
    assert(_isAdmin(message.caller));
    pause :=pause_;
    pause_;
  } ;
  func _isNotRegistered(p : Principal, username_ : Text ): Bool {
    
     let minerList = Buffer.mapFilter<T.Miner,T.Miner >(miners, func (miner) {
        if (miner.walletAddress==p or miner.username == username_) {
          ?miner;     
        } else {
          null;
        }
      
      });
      let miners_ = Buffer.toArray<T.Miner>(minerList);
      let minersFound = Array.size(miners_);
    if(minersFound > 0)return false;
    true;

  };


  func _isRegistered(p : Principal, username_ : Text) : Bool {
    if(_isNotRegistered(p,username_))return false;
    true;
  };

  func _isVerified(p : Principal, username_ : Text) : Bool {
    if(_isNotRegistered(p,username_))return false;

    let miners_ = getMiner(p);
    let miner_ = miners_[0];
    let minerStatus_ = minerStatus.get(miner_.id);
    minerStatus_.verified;
  };



   /*public query(message) func isVerified(username_ : Text) : async Bool {
    if(_isNotRegistered(message.caller,username_))return false;

    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    let minerStatus_ = minerStatus.get(miner_.id);
    minerStatus_.verified;
  };*/

 public query(message) func isVerified(p : Principal) : async Bool {
    let miners_ = getMiner(p);
    if(Array.size(miners_)==0){return false;};
    true;
  };

  func _isAddressVerified(p : Principal) :  Bool {
    let miners_ = getMiner(p);
    if(Array.size(miners_)==0){return false;};
    true;
  };


  func _isNotVerified(p : Principal, username_ : Text) : Bool {
    if(_isVerified(p,username_))return false;
    true;
  };
  
  public shared(message) func setDappsKey(key : Text) : async Text {
    assert(_isAdmin(message.caller));
    dappsKey := key;
    key;
  };

   public shared(message) func setF2PoolKey(key : Text) : async Text {
    assert(_isAdmin(message.caller));
    f2poolKey := key;
    key;
  };
  private func addMiner(f2poolUsername_ : Text, hashrate_ : Nat, wallet : Principal) : async Bool {
    //assert(_isAdmin(message.caller));
    assert(_isNotRegistered(wallet,f2poolUsername_));
    assert(_isNotPaused());
    let miner_ = getMiner(wallet);
    let hash_ = hashrate_* 1000000000000;
    if(_isNotRegistered(wallet, f2poolUsername_)){
      let miner_ : T.Miner= {
    
        id = minersIndex;
        walletAddress = wallet;
        var username = f2poolUsername_;
        hashrate = hash_;
      };

      miners.add(miner_);
      Debug.print("miner added");
      logMiner(minersIndex,f2poolUsername_, Nat.toText(hashrate_));
      minerStatus.add({id = minersIndex; var verified = true; var balance = 0; var totalWithdrawn = 0; var walletAddress = []; var bankAddress = []; var transactions = []});
      //minerRewards.add({id = minersIndex; var available = 0.0; var claimed = 0.0});
      minersIndex+=1;
      totalHashrate +=hash_;
      true;
    }else{
      //update mining Pool
      false;
    };
    
  };


  public query(message) func getBalance() : async Nat {
    totalBalance;
  };

  public query(message) func getWithdrawn() : async Nat {
    totalBalance;
  };
  public shared(message) func getCKBTCBalance() : async Nat {
     var ckBTCBalance : Nat= (await CKBTC.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null}));
     ckBTCBalance;
  };

   //public shared(message) func getCKBTCMintAddress() : async Text {
    // var ckBTCBalance : Nat= (await CKBTC.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null}));
     //ckBTCBalance;
  //};

  public shared(message) func sendCKBTC(wallet_ : Text ) : async Bool {
    let wallet : Principal = Principal.fromText(wallet_);
    assert(_isAdmin(message.caller));
    var ckBTCBalance : Nat= (await CKBTC.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null}));
    //assert(ckBTCBalance>12);
    ckBTCBalance -=12;

    let transferResult = await CKBTC.icrc1_transfer({
      amount = ckBTCBalance;
      fee = ?10;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=wallet; subaccount=null};
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
        
      };
      case (#Err(msg)) {res:=0;};
    }; 
    true; 
  };

  func btcToSats(btc : Float) : Int {
    let sats = 100000000* btc;
    Float.toInt(sats);
  };

  func textToNat( txt : Text) : Nat {
        assert(txt.size() > 0);
        let chars = txt.chars();

        var num : Nat = 0;
        for (v in chars){
            let charToNum = Nat32.toNat(Char.toNat32(v)-48);
            assert(charToNum >= 0 and charToNum <= 9);
            num := num * 10 +  charToNum;          
        };

        num;
    };

  public shared(message) func withdrawCKBTC(username_ : Text, amount_ : Nat, address : Text) : async Bool {
    assert(_isNotPaused());
    assert(_isVerified(message.caller, username_));
    let addr = Principal.fromText(address);
    let amountNat_ : Nat = amount_;
    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id);


    
    let transferResult = await CKBTC.icrc1_transfer({
      amount = amountNat_;
      fee = ?10;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=addr; subaccount=null};
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
        minerStatus_.totalWithdrawn+=amount_;
        totalBalance-=amount_;
        totalWithdrawn+=amount_;
        logTransaction(miner_.id,"withdraw CKBTC", Nat.toText(amount_), Int.toText(number), "CKBTC");
      };
      case (#Err(msg)) {res:=0;};
    };
    
    

    true;
  };

  func logTransaction(id_ : Nat,action_: Text, amount_: Text, txid_ : Text, currency_ : Text){
    let transaction : T.TransactionHistory = {
        id = transactionIndex;
        //caller = caller_;
        time = now();
        action = action_;
        amount = amount_;
        txid = txid_;
        currency = currency_;
    };
  
    let array_ : [T.TransactionHistory]= [transaction];
    let status_ = minerStatus_.get(id_);
    status_.transactions := Array.append<T.TransactionHistory>(status_.transactions, array_);

    transactions.add(transaction);
    transactionIndex +=1;
  };

  func logMiner (id_ : Nat, username_ : Text, hash_ : Text){
    let transaction : T.TransactionHistory = {
        id = transactionIndex;
        //caller = caller_;
        time = now();
        action = "new miner";
        amount = hash_;
        txid = username_;
        currency = "";
    };
   

    transactions.add(transaction);
    transactionIndex +=1;
  };
   /*public shared(message) func mintCKBTC(amount_ : Float, address : Text) : async Bool {
    
    let addr = Principal.fromText(address);
    let amountNat_ : Nat = textToNat(Int.toText(btcToSats(amount_)));
    
    let transferResult = await CKBTC.icrc1_transfer({
      amount = amountNat_;
      fee = ?10;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=addr; subaccount=null};
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
        
      };
      case (#Err(msg)) {res:=0;};
    };

    true;
  };*/

  //http://146.190.146.168:3000/transfer




  public shared(message) func withdrawUSDT(username_ : Text, amount_ : Nat, addr_ : Text, usd_ : Text) : async Text {
    assert(_isNotPaused());
    assert(_isVerified(message.caller, username_));
    let amountNat_ : Nat = amount_;
    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id); 


   let ic : T.IC = actor ("aaaaa-aa");
    let uid_ = addr_#usd_#Int.toText(now());
   let url = "https://api.lokamining.com/transfer?targetAddress="#addr_#"&amount="#usd_#"id="#uid_;
   let decoded_text = await send_http(url);
   
    Debug.print("result "#decoded_text);
    var isValid = Text.contains(decoded_text,#text "transfersuccess");
    if (isValid){
      let hashtext_ = textSplit(decoded_text,'/');
      let res = await moveCKBTC(amount_);
      if(res){
        minerStatus_.totalWithdrawn+= amount_;
        totalBalance-=amount_;
        totalWithdrawn+=amount_;
      };
      return "USDT transferred";
      logTransaction(miner_.id,"withdraw USDT", Nat.toText(amount_), hashtext_[1], "USDT");
      //return true;
    };
   
    decoded_text;
  };


  func moveCKBTC(amount_ : Nat) : async Bool {
    assert(_isNotPaused());

    let amountNat_ : Nat = amount_;
    
    let transferResult = await CKBTC.icrc1_transfer({
      amount = amountNat_;
      fee = ?10;
      created_at_time = null;
      from_subaccount=null;
      to = {owner=lokaCKBTCVault; subaccount=null};
      memo = null;
    });
    var res = 0;
    switch (transferResult)  {
      case (#Ok(number)) {
        return true;
      };
      case (#Err(msg)) {return false;};
    };


    false;
  };


  func send_http(url_ : Text) : async Text {
      let ic : T.IC = actor ("aaaaa-aa");

      let url = url_;
      //let url = "https://api.lokamining.com/transfer?targetAddress=0xc66fB343f20765CC923b2e79aD8c95FA9ef407fe&amount=blabla";
      //let url = "https://loka-miners.vercel.app/api/withdraw?targetAddress="#addr_#"&amount="#usd_;
      //let url = "https://api.lokamining.com";
        let request_headers = [
            { name = "User-Agent"; value = "miner_canister" },
            { name = "Content-Type"; value = "application/json" },
            { name = "x-api-key"; value = "2021LokaInfinity" },
            { name = "F2P-API-SECRET"; value = f2poolKey },
        ];
      Debug.print("accessing "#url);
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
        let response_body: Blob = Blob.fromArray(http_response.body);
        let decoded_text: Text = switch (Text.decodeUtf8(response_body)) {
            case (null) { "No value returned" };
            case (?y) { y };
        };
        decoded_text;
  };


  public shared(message) func testUSDT() : async Text {

    let id_ = "0xc66fB343f20765CC923b2e79aD8c95FA9ef407fe"#Int.toText(now());
    let url = "https://api.lokamining.com/transfer?targetAddress=0xafb922cc57E3CD934eFf590Fa8Cfc55B4B7d57e7&amount=0.01&id="#id_;
    let decoded_text = await send_http(url);
    Debug.print("result "#decoded_text);
    var isValid = Text.contains(decoded_text,#text ":true");
    if (isValid){
       //let res = await moveCKBTC(amount_);
      
      return "USDT transferred "#decoded_text;
      //return true;
    };
   
    decoded_text;
  };



  private func natToFloat (nat_ : Nat ) : Float {
    let toNat64_ = Nat64.fromNat(nat_);
    let toInt64_ = Int64.fromNat64(toNat64_);
    let amountFloat_ = Float.fromInt64(toInt64_);
    return amountFloat_;
  };
  

  func getMiner(wallet_ : Principal) : [T.Miner] {
    var miner_id : Nat = 0;
     let minerList = Buffer.mapFilter<T.Miner,T.Miner >(miners, func (miner) {
        if (miner.walletAddress==wallet_) {
          miner_id :=miner.id;
          ?miner;     
        } else {
          null;
        }
      
      });
      Buffer.toArray<T.Miner>(minerList);
  };

  public query(message) func getMinerData() : async T.MinerData {
    Debug.print(Principal.toText(message.caller)#" being checked");
    assert(_isAddressVerified(message.caller));
    //Debug.print(Principal.toText(message.caller)#" is exist");
    let miners_ = getMiner(message.caller);
    
    let miner_ = miners_[0];
    //Debug.print("fetched "#Nat.toText(miner_.id));
    Debug.print("number of Miner detected for "#Principal.toText(message.caller)#" "#Nat.toText(miner_.id));
    let status_ = minerStatus.get(miner_.id);
    Debug.print("fetched next "#Nat.toText(miner_.id));
    //let reward_ = minerRewards.get(miner_.id);
    Debug.print("fetched 2");
    let minerData : T.MinerData = {
        id  = miner_.id;
        walletAddress = miner_.walletAddress;
        walletAddressText = Principal.toText(miner_.walletAddress);
        username = miner_.username;
        hashrate = miner_.hashrate;
        verified = status_.verified;
        balance = status_.balance;
        totalWithdrawn = status_.totalWithdrawn;
  
        savedWalletAddress = status_.walletAddress;
        bankAddress = status_.bankAddress;
    };
    Debug.print("fetched 3");
    minerData;
  };

  public query(message) func getWallets(id_ : Nat) : async [T.WalletAddress]{
    
    let miner_ = minerStatus.get(id_);
    //Debug.print(miner_.walletAddress[0]);
    miner_.walletAddress;
  };

  public shared(message) func saveWalletAddress(name_ : Text, address_ : Text, currency_ : Text) : async Bool {
    
    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    let status_ = minerStatus.get(miner_.id);
    let isthere = Array.find<T.WalletAddress>(status_.walletAddress, func wallet = wallet.address == address_);
    assert(isthere==null);
    let wallet_ : [T.WalletAddress] = [{name = name_; address =address_; currency =currency_;}];
    status_.walletAddress:=Array.append<T.WalletAddress>(status_.walletAddress,wallet_);
    true;
  };

  public shared(message) func saveBankAddress(name_ : Text, account_ : Text, bankName_ : Text) : async Bool {
    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    let status_ = minerStatus.get(miner_.id);
    let isthere = Array.find<T.BankAddress>(status_.bankAddress, func bank = bank.accountNumber == account_);
    assert(isthere==null);
    let bank_ : [T.BankAddress] = [{name = name_; accountNumber=account_; bankName = bankName_}];
    status_.bankAddress:=Array.append<T.BankAddress>(status_.bankAddress,bank_);
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

  func hello(){

  };
  //need a timer to check balance every 24 hrs
  public shared(message) func routine24() : async Text {
      assert(_isAdmin(message.caller));
      let now_ = now();
      let seconds_ = abs(now_/1000000000)-abs(lastF2poolCheck/1000000000);
      let daySeconds_ = 3600*24;
      //if(seconds_ < daySeconds_){return "false";};
     // assert(_isAdmin(message.caller));
      let url = "https://api.lokamining.com/calculatef2poolReward";
      //let hashrateRewards= await send_http(url);
      let hashrateRewards = "rantai1-lokabtc/0.0135669;rantai2-lokabtc/0.0136183;";
      distributeMiningRewards(hashrateRewards);
      Debug.print(hashrateRewards);
      lastF2poolCheck:=now_;
      hashrateRewards;
  };

  func textSplit(word_ : Text, delimiter_ : Char) : [Text]{
    let hasil = Text.split(word_, #char delimiter_);
    let wordsArray = Iter.toArray(hasil);
    return wordsArray;
    //Debug.print(wordsArray[0]);
  };
  


  func distributeMiningRewards(rewards_ : Text) {

    let hashrateRewards = textSplit(rewards_,';');   
    Buffer.iterate<T.Miner>(miners, func (miner) {
     // Debug.print("try "#Nat.toText(miner.id));
      
      //Debug.print("get "#Nat.toText(minerStatus.size()));
      //return ;
      let status_ = minerStatus.get(miner.id);
      
      let user_ = miner.username;
      
      let isValid = Text.contains(rewards_,#text user_);
      if(isValid){
        for (hashrateRewards_ in hashrateRewards.vals()) {
          if(hashrateRewards_!=""){
            Debug.print("split "#hashrateRewards_);
            let hr_ = textSplit(hashrateRewards_,'/'); 
            var username = hr_[0];
            var reward = textToFloat(hr_[1]);
            Debug.print("miner username : "#username#" "#miner.username);
            if(username == miner.username#"-lokabtc"){
              Debug.print("distributing "#Float.toText(reward));
              //status_.balance += reward;
            };
          };
      };
        }else{
          status_.verified:=false;
        };
    });   
  };


 public shared(message) func verifyMiner(uname : Text, hash_ : Nat) : async Bool {
   assert(_isNotVerified(message.caller,uname));
   let url = "https://api.f2pool.com/bitcoin/lokabtc/"#uname#"-lokabtc";

   let decoded_text = await send_http(url);
   
    let hashText = Nat.toText(hash_);
    var isValid = Text.contains(decoded_text,#text hashText);
    if(isValid){
      let miner_ = addMiner(uname, hash_, message.caller);
    };
    isValid;

  };

  func removeMiner(p_ : Principal) : async Bool {
    let miners_ = getMiner(p_);
    let miner_ = miners_[0];
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id);
    minerStatus_.verified:=false;
    miner_.username:="";

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
  }

};