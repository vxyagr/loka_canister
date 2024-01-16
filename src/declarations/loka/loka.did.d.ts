import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export interface Loka {
  'addMiningSite' : ActorMethod<
    [string, string, number, number, bigint, string, string],
    bigint
  >,
  'getMiningSiteStatus' : ActorMethod<[bigint], boolean>,
  'getMiningSites' : ActorMethod<[], Array<MiningSite>>,
  'setMiningStatus' : ActorMethod<[bigint, boolean], boolean>,
}
export interface MiningSite {
  'id' : bigint,
  'controllerCanisterId' : string,
  'dollarPerHashrate' : number,
  'name' : string,
  'totalHashrate' : bigint,
  'electricityPerKwh' : number,
  'nftCanisterId' : string,
  'location' : string,
}
export interface _SERVICE extends Loka {}
