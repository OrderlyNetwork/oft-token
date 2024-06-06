## Orderly Fuzz Suite

### Overview

This fuzzing suite consists of a contract that define different setUp parameters:
* OrderInvariant.t.sol

OrderInvariant configures an OFT system that contains 10 endpoints.
The system contains the OrderToken, as well as, its OFT adapter. 
The rest of the endpoints are connected to OrderOFT Instances.

All of the invariants reside in the following contracts:
* OrderHandler.sol
* BaseInvariant.t.sol

With OrderHandler.sol containing conditional invariants and BaseInvariant containing global invariants.

The Suite also contains a contract to assist in verification methods: VerifyHelper.sol

To run invariant tests:
```shell
forge test
```

### Invariants
| **Invariant ID** | **Invariant Description** | **Passed** | **Run Count** |
|:--------------:|:-----|:-----------:|:-----------:|
| **OT-01** | Total Supply of ORDER should always be 1,000,000,000 | PASS | 1,000,000+
| **OT-02** | Allowance Matches Approved Amount | PASS | 1,000,000+
| **OT-03** | ERC20 Balance Changes By Amount For Sender And Receiver Upon Transfer | PASS | 1,000,000+
| **OT-04** | ERC20 Balance Remains The Same Upon Self-Transfer | PASS | 1,000,000+
| **OT-05** | ERC20 Total Supply Remains The Same Upon Transfer | PASS | 1,000,000+
| **OT-06** | Source Token Balance Should Decrease On Send | PASS | 1,000,000+
| **OT-07** | Adapter Balance Should Increase On Send | PASS | 1,000,000+
| **OT-08** | Native Token Total Supply Should Not Change On Send | PASS | 1,000,000+
| **OT-09** | Source OFT Total Supply Should Decrease On Send | PASS | 1,000,000+
| **OT-10** | Outbound Nonce Should Increase By 1 | PASS | 1,000,000+
| **OT-11** | Max Received Nonce Should Increase By 1 on lzReceive | PASS | 1,000,000+
| **OT-12** | Destination Token Balance Should Increase on lzReceive | PASS | 1,000,000+
| **OT-13** | Adapter Balance Should Decrease on lzReceive | PASS | 1,000,000+
| **OT-14** | Native Token Total Supply Should Not Change on lzReceive | PASS | 1,000,000+
| **OT-15** | Destination Total Supply Should Increase on lzReceive | PASS | 1,000,000+
