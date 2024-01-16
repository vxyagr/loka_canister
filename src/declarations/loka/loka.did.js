export const idlFactory = ({ IDL }) => {
  const MiningSite = IDL.Record({
    'id' : IDL.Nat,
    'controllerCanisterId' : IDL.Text,
    'dollarPerHashrate' : IDL.Float64,
    'name' : IDL.Text,
    'totalHashrate' : IDL.Nat,
    'electricityPerKwh' : IDL.Float64,
    'nftCanisterId' : IDL.Text,
    'location' : IDL.Text,
  });
  const Loka = IDL.Service({
    'addMiningSite' : IDL.Func(
        [
          IDL.Text,
          IDL.Text,
          IDL.Float64,
          IDL.Float64,
          IDL.Nat,
          IDL.Text,
          IDL.Text,
        ],
        [IDL.Nat],
        [],
      ),
    'getMiningSiteStatus' : IDL.Func([IDL.Nat], [IDL.Bool], ['query']),
    'getMiningSites' : IDL.Func([], [IDL.Vec(MiningSite)], ['query']),
    'setMiningStatus' : IDL.Func([IDL.Nat, IDL.Bool], [IDL.Bool], []),
  });
  return Loka;
};
export const init = ({ IDL }) => {
  return [IDL.Record({ 'admin' : IDL.Principal })];
};
