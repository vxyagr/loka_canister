# Loka
Loka is a new decentralized protocol that enables direct acquisition of bitcoin through mining rewards and network fees. By using Loka, retail investors are able to make, by facilitating co-investments with Bitcoin miners.
A trustless, collateralized, decentralized, and composable bitcoin mining platform.

https://lokamining.com
One paragraph of project description goes here. Things to include:
- What is the primary functionality of this project?
- What is the purpose of this project?
- How does it look like in action? Have any screenshots, videos etc.?
- Link to the live version/canister, if there is one

## Introduction
This project is a set of Motoko canister implementing trustless, decentralized, and collateralized bitcoin mining platform.
It handles business models for 3 actors : the miners, collateral providers, and retail investors.
Loka run on Internet Computer, leveraging ckBTC, a non-custodial bitcoin wrapper, allowing users to safely use bitcoin transaction in an extremely faster execution.

In this protocol:
- Miner can transfer their hashrate to Loka, and creating Stash and Troves to be sold to retail investors.
- Retail investor can rent hashrate from miner and directly claim ckBTC to their wallet as mining rewards.
- Collateral provider can deposit their collateral to the miners they trust, and claim profit from transactions.

This is how the business model is represented by ICP canisters. 

![Illustration Example](local-workflow.png)
![Image](local-workflow.png)
## Installation
Step-by-step guide to get a copy of the project up and running locally for development and testing.

### Prerequisites
IC SDK (https://internetcomputer.org/docs/current/developer-docs/setup/install/) (Mac/Linux and Windows with WSL)


### Install
A step-by-step guide to installing the project, including necessary configuration etc.

```bash
$ git clone <GitHub repo>
$ cd <project>
$ npm install
$ dfx start --background
$ dfx deploy // deploy local ckBTC token
$ dfx deploy // deploy local LOM token
$ dfx deploy // deploy local ckUSD token
```



## Usage
Most projects have a frontend, so link to the canister and provide a brief getting-started instruction. If the project has a backend that may be called without a frontend, which is typically the case for developer libraries, tooling, infrastructure etc., then provide some basic examples of how to use it. 

### Example 1
Usage examples can be canister calls:

```bash
$ dfx canister call mycanister myfunc '("abc")'
```

### Example 2
If the project is added as a separate canister, show how to access the functions.

```javascript
import MyFunc  "mo:myproj/MyFunc";  

private let myFunc = MyFunc.MyFunc();

...

let value = myFunc("abc");

...
```

## Documentation
Further documentation can exist in the README file if the project only contains a few functions. It can also be located elsewhere, if it is extensive, if this is the case, link to it.  



## Roadmap
Describe the project roadmap, this could be the grant milestones, but it could also be the team's broader project roadmap.

- [Q4 2023] Alpha Launch - Miner Dashboard.
- [Q1 2024] Lokamining Launch. 
- [Q2 2024] Trove Bear and Bull Vault. 


## License
This project is licensed under the MIT license, see LICENSE.md for details. See CONTRIBUTE.md for details about how to contribute to this project. 

## Acknowledgements
- Hat tip to anyone who's code was used
- External contributors
- Etc.

## References
- [Internet Computer](https://internetcomputer.org)



