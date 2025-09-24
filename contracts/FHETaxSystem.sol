// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { FHE, euint32, externalEuint32 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract FHETaxSystem is SepoliaConfig {
    
    struct TaxPayer {
        address wallet;
        euint32 taxAmount; 
        euint32 paidAmount;
    }
    
    mapping(address => TaxPayer) public taxpayers;
    address[] public taxpayerAddresses;
    
    address public taxAuthority;
    
    event TaxPaid(address indexed taxpayer, uint256 timestamp);
    event TaxDebtCleared(address indexed taxpayer, uint256 year);
    event TaxPayerAdded(address indexed taxpayer);
    event TaxAmountUpdated(address indexed taxpayer, uint256 timestamp);
    
    modifier onlyTaxAuthority() {
        require(msg.sender == taxAuthority, "Only tax authority can call this");
        _;
    }
    
    constructor() {
        taxAuthority = msg.sender;
    }
    
    function addTaxPayer(
        address taxpayerAddress, 
        externalEuint32 encryptedTaxAmount, 
        bytes calldata taxProof
    ) external onlyTaxAuthority {
        
        euint32 taxAmount = FHE.fromExternal(encryptedTaxAmount, taxProof);
        
        taxpayers[taxpayerAddress] = TaxPayer({
            wallet: taxpayerAddress,
            taxAmount: taxAmount,
            paidAmount: FHE.asEuint32(0) 
        });
        
        taxpayerAddresses.push(taxpayerAddress);
        
        FHE.allowThis(taxAmount);
        FHE.allow(taxAmount, taxpayerAddress);
        
        emit TaxPayerAdded(taxpayerAddress);
    }
    
    function payTax(
        externalEuint32 encryptedPaymentAmount, 
        bytes calldata paymentProof
    ) external {
        
        TaxPayer storage taxpayer = taxpayers[msg.sender];
        
        euint32 paymentAmount = FHE.fromExternal(encryptedPaymentAmount, paymentProof);
        
        taxpayer.paidAmount = FHE.add(taxpayer.paidAmount, paymentAmount);
        
        checkTaxPayment(msg.sender);

        FHE.allowThis(taxpayer.paidAmount);
        FHE.allow(taxpayer.paidAmount, msg.sender);
        
        emit TaxPaid(msg.sender, block.timestamp);
    }

     function setTaxAmount(
        address taxpayerAddress,
        externalEuint32 encryptedNewTaxAmount, 
        bytes calldata taxProof 
    ) external onlyTaxAuthority{
        
        TaxPayer storage taxpayer = taxpayers[taxpayerAddress];
        
        euint32 newTaxAmount = FHE.fromExternal(encryptedNewTaxAmount, taxProof);

        taxpayer.taxAmount = newTaxAmount;
        
        FHE.allowThis(newTaxAmount);
        FHE.allow(newTaxAmount, taxpayerAddress);
        
        emit TaxAmountUpdated(taxpayerAddress, block.timestamp);
    }
    
    function checkTaxPayment(address taxpayerAddress) public returns (bool) {
        
        TaxPayer storage taxpayer = taxpayers[taxpayerAddress];
        
        if (FHE.isInitialized(FHE.le(taxpayer.taxAmount, taxpayer.paidAmount))) {
            return true;
        }
        return false;
    }
    
    function verifyTaxPayment(address taxpayerAddress) external onlyTaxAuthority returns (bool) {
        return checkTaxPayment(taxpayerAddress);
    }
    
    
    function getAllTaxpayers() external view onlyTaxAuthority returns (address[] memory) {
        return taxpayerAddresses;
    }
    
    function setTaxAuthority(address newAuthority) external onlyTaxAuthority {
        taxAuthority = newAuthority;
    }
}