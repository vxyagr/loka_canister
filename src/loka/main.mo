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


import T "types";


shared ({ caller = owner }) actor class Loka({
  admin: Principal
}) {

  private var miningSiteIndex = 0;
  private var pause = false : Bool;
  private var totalConsumedHashrate = 0;
  private var siteAdmin : Principal = admin;

  let miningSiteStatus = Buffer.Buffer<T.MiningSiteStatus>(0);
  let miningSites = Buffer.Buffer<T.MiningSite>(0);

  func _isAdmin(p : Principal) : Bool {
      return (p == siteAdmin);
    };

  public shared(message) func addMiningSite(location_ : Text, name_: Text, elec_ : Float, thCost_ : Float, total_ : Nat, nftCan_ : Text, controlCan_ : Text) : async Nat {
    assert(_isAdmin(message.caller));
    let miningSite_ : T.MiningSite= {
        id = miningSiteIndex;
        location = location_;
        name = name_;
        totalHashrate = total_;
        dollarPerHashrate = thCost_;
        electricityPerKwh = elec_;
        nftCanisterId = nftCan_;
        controllerCanisterId = controlCan_;
      };
    
    miningSites.add(miningSite_);
    miningSiteStatus.add({id = miningSiteIndex; var status = true});
    miningSiteIndex+=1;
    miningSiteIndex;
  };

  public query(message) func getMiningSites() : async [T.MiningSite] {
    Buffer.toArray<T.MiningSite>(miningSites);
  };

  public shared(message) func setMiningStatus(id_ : Nat, status_ : Bool) : async Bool {

    var miningSiteStatus_ : T.MiningSiteStatus = miningSiteStatus.get(id_);
    miningSiteStatus_.status := status_;
    miningSiteStatus.put(id_,miningSiteStatus_);

    status_;
  };

  public query(message) func getMiningSiteStatus(id_ : Nat) : async Bool {
    var miningSiteStatus_ : T.MiningSiteStatus = miningSiteStatus.get(id_);
    miningSiteStatus_.status;
  };

};