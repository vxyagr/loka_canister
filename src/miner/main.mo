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



import T "types";
import CKBTC "canister:ckbtc_ledger";

shared ({ caller = owner }) actor class Miner({
  admin: Principal
}) =this{

  private stable var minersIndex = 0;
  private stable var pause = false : Bool;
  private var totalConsumedHashrate = 0;
  private var siteAdmin : Principal = admin;
  private var dappsKey = "0xSet";
  private stable var totalHashrate = 0;
  private var totalBalance = 0.0005;
  private var totalWithdrawn = 0.0;



  var minerStatus = Buffer.Buffer<T.MinerStatus>(0);
  var miners = Buffer.Buffer<T.Miner>(0);
  var minerStatus_ : [T.MinerStatus]= []; 
  var miners_ : [T.Miner]= []; 
  var minerRewards = Buffer.Buffer<T.MinerReward>(0);
  var lokaCKBTCVault : Principal = admin; 
  var f2poolKey : Text = "gxq33xia5tdocncubl0ivy91aetpiqm514wm6z77emrruwlg0l1d7lnrvctr4f5h";

  system func preupgrade() {
        miners_ := Buffer.toArray<T.Miner>(miners);
        minerStatus_ := Buffer.toArray<T.MinerStatus>(minerStatus);
  };
  system func postupgrade() {
        miners := Buffer.fromArray<T.Miner>(miners_); 
        minerStatus:= Buffer.fromArray<(T.MinerStatus)>(minerStatus_);
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

   public query(message) func isVerified(username_ : Text) : async Bool {
    if(_isNotRegistered(message.caller,username_))return false;

    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    let minerStatus_ = minerStatus.get(miner_.id);
    minerStatus_.verified;
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
        username = f2poolUsername_;
        hashrate = hash_;
      };

      miners.add(miner_);
      minerStatus.add({id = minersIndex; var verified = true; var lastCheckedBalance = 0.0; var totalWithdrawn = 0.0});
      minerRewards.add({id = minersIndex; var available = 0.0; var claimed = 0.0});
      minersIndex+=1;
      totalHashrate +=hash_;
      true;
    }else{
      //update mining Pool
      false;
    };
    
  };

  public query(message) func getMiners() : async [T.Miner] {
    assert(_isAdmin(message.caller));
    Buffer.toArray<T.Miner>(miners);
  };

  public query(message) func getBalance() : async Float {
    totalBalance;
  };

  public query(message) func getWithdrawn() : async Float {
    totalBalance;
  };
  public shared(message) func getCKBTCBalance() : async Nat {
     var ckBTCBalance : Nat= (await CKBTC.icrc1_balance_of({owner=Principal.fromActor(this);subaccount=null}));
     ckBTCBalance;
  };

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

  public shared(message) func withdrawCKBTC(username_ : Text, amount_ : Float, address : Text) : async Bool {
    assert(_isNotPaused());
    assert(_isVerified(message.caller, username_));
    let addr = Principal.fromText(address);
    let amountNat_ : Nat = textToNat(Int.toText(btcToSats(amount_)));
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
      };
      case (#Err(msg)) {res:=0;};
    };
    totalBalance-=amount_;
    totalWithdrawn+=amount_;

    true;
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




  public shared(message) func withdrawUSDT(username_ : Text, amount_ : Float, addr_ : Text, usd_ : Text) : async Bool {
    assert(_isNotPaused());
    assert(_isVerified(message.caller, username_));
    let amountNat_ : Nat = textToNat(Int.toText(btcToSats(amount_)));
    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id); 


   let ic : T.IC = actor ("aaaaa-aa");

   let url = "https://api.lokamining.com/transfer?targetAddress="#addr_#"&amount="#usd_;
   //let url = "https://loka-miners.vercel.app/api/withdraw?targetAddress="#addr_#"&amount="#usd_;
   
    let request_headers = [
        { name = "User-Agent"; value = "miner_canister" },
        { name = "Content-Type"; value = "application/json" },
        { name = "x-api-key"; value = "2021LokaInfinity" },
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

    if (decoded_text=="true"){
       let res = await moveCKBTC(amount_);
      if(res){
        minerStatus_.totalWithdrawn+= amount_;
        totalBalance-=amount_;
        totalWithdrawn+=amount_;
      };
      return res;
      //return true;
    };
   
    false;
  };


  func moveCKBTC(amount_ : Float) : async Bool {
    assert(_isNotPaused());

    let amountNat_ : Nat = textToNat(Int.toText(btcToSats(amount_)));
    
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
    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    let status_ = minerStatus.get(miner_.id);
    let reward_ = minerRewards.get(miner_.id);
    let minerData : T.MinerData = {
        id  = miner_.id;
        walletAddress = miner_.walletAddress;
        walletAddressText = Principal.toText(miner_.walletAddress);
        username = miner_.username;
        hashrate = miner_.hashrate;
        verified = status_.verified;
        lastCheckedBalance = status_.lastCheckedBalance;
        totalWithdrawn = status_.totalWithdrawn;
        available = reward_.available;
        claimed = reward_.claimed;
    };
    minerData;
  };

  //need a timer to check balance every 24 hrs
  public shared(message) func distributeF2PoolReward() : async Bool {
   let ic : T.IC = actor ("aaaaa-aa");
   let url = "https://api.f2pool.com/bitcoin/lokabtc";
    let request_headers = [
        { name = "User-Agent"; value = "miner_canister" },
        { name = "Content-Type"; value = "application/json" },
        { name = "F2P-API-SECRET"; value = f2poolKey },
    ];

    let transform_context : T.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    // Finally, define the HTTP request.

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
    Debug.print(decoded_text);
    true;
  };

  /*public shared(message) func minerCheckin(id_ : Nat, status_ : Bool) : async Float {

    //assert(_isNotVerified(message.caller,uname));
   let ic : T.IC = actor ("aaaaa-aa");
   let url = "https://api.f2pool.com/bitcoin/lokabtc";
    let request_headers = [
        { name = "User-Agent"; value = "miner_canister" },
        { name = "Content-Type"; value = "application/json" },
        { name = "F2P-API-SECRET"; value = "gxq33xia5tdocncubl0ivy91aetpiqm514wm6z77emrruwlg0l1d7lnrvctr4f5h" },
    ];

    let transform_context : T.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    // Finally, define the HTTP request.

    let http_request : T.HttpRequestArgs = {
        url = url;
        max_response_bytes = null; //optional for request
        headers = request_headers;
        body = null; //optional for request
        method = #get;
        transform = ?transform_context;
    };

    Cycles.add(2_000_000_000);


    let http_response : T.HttpResponsePayload = await ic.http_request(http_request);
     let response_body: Blob = Blob.fromArray(http_response.body);
    let decoded_text: Text = switch (Text.decodeUtf8(response_body)) {
        case (null) { "No value returned" };
        case (?y) { y };
    };
    let hashText = Nat.toText(hash_);
    var isValid = Text.contains(decoded_text,#text hashText);
    
    100.0

  }; */


  func distributeMiningRewards(btcAmount : Float) {
    Buffer.iterate<T.Miner>(miners, func (miner) {
      let reward_ = minerRewards.get(miner.id);
      
      
    });
    
  };


 public shared(message) func verifyMiner(uname : Text, hash_ : Nat) : async Bool {
   assert(_isNotVerified(message.caller,uname));
   let ic : T.IC = actor ("aaaaa-aa");
   let url = "https://api.f2pool.com/bitcoin/lokabtc/"#uname#"-lokabtc";
    let request_headers = [
        { name = "User-Agent"; value = "miner_canister" },
        { name = "Content-Type"; value = "application/json" },
        { name = "F2P-API-SECRET"; value = f2poolKey },
    ];

    let transform_context : T.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    // Finally, define the HTTP request.

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
    let hashText = Nat.toText(hash_);
    var isValid = Text.contains(decoded_text,#text hashText);
    if(isValid){
      let miner_ = addMiner(uname, hash_, message.caller);
    };
    isValid;

  };

  public shared(message) func unverifySelf() : async Bool {
    let miners_ = getMiner(message.caller);
    let miner_ = miners_[0];
    var minerStatus_ : T.MinerStatus = minerStatus.get(miner_.id);
    minerStatus_.verified:=false;
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

};