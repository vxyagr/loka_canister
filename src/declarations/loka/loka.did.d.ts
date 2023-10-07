import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export interface MiningContract {
  'id' : bigint,
  'end' : bigint,
  'duration' : bigint,
  'hashrate' : bigint,
  'genesisId' : bigint,
  'electricityPerDay' : bigint,
  'start' : bigint,
  'amount' : bigint,
}
export interface NFTContract {
  'id' : bigint,
  'end' : bigint,
  'claimedBTC' : bigint,
  'claimedLOM' : bigint,
  'duration' : bigint,
  'hashrate' : bigint,
  'owner' : string,
  'metadata' : string,
  'electricityPerDay' : bigint,
  'start' : bigint,
  'LETBalance' : bigint,
  'amount' : bigint,
  'daysLeft' : bigint,
  'claimableBTC' : bigint,
  'claimableLOM' : bigint,
}
export interface _SERVICE {
  'claimBTC' : ActorMethod<[], bigint>,
  'claimLOM' : ActorMethod<[], bigint>,
  'distributeBTC' : ActorMethod<[bigint, bigint], bigint>,
  'distributeLOM' : ActorMethod<[bigint], bigint>,
  'getContract' : ActorMethod<[bigint], MiningContract>,
  'getContractAmount' : ActorMethod<[bigint], string>,
  'getOwnedContracts' : ActorMethod<[], Array<NFTContract>>,
  'greet' : ActorMethod<[], string>,
  'mintContract' : ActorMethod<
    [bigint, bigint, bigint, bigint, bigint, bigint, bigint],
    bigint
  >,
  'pauseContract' : ActorMethod<[boolean], boolean>,
  'rechargeLET' : ActorMethod<[bigint, bigint], bigint>,
}
