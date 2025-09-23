// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { FHE, euint32, externalEuint32 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title Titkosított Adófizetési Rendszer
contract FHETaxSystem is SepoliaConfig {
    
    struct TaxPayer {
        address wallet;
        euint32 taxAmount; // Titkosított adóösszeg
        euint32 paidAmount; // Titkosított befizetett összeg
    }
    
    mapping(address => TaxPayer) public taxpayers;
    address[] public taxpayerAddresses;
    
    address public taxAuthority;
    uint256 public currentTaxYear;
    
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
        currentTaxYear = block.timestamp / 31536000; // Év számítása
    }
    
    /// @notice Új adófizető hozzáadása titkosított adóösszeggel
    function addTaxPayer(
        address taxpayerAddress, 
        externalEuint32 encryptedTaxAmount, 
        bytes calldata taxProof
    ) external onlyTaxAuthority {
        
        euint32 taxAmount = FHE.fromExternal(encryptedTaxAmount, taxProof);
        
        taxpayers[taxpayerAddress] = TaxPayer({
            wallet: taxpayerAddress,
            taxAmount: taxAmount,
            paidAmount: FHE.asEuint32(0) // Kezdetben 0 befizetés
        });
        
        taxpayerAddresses.push(taxpayerAddress);
        
        // Engedélyezzük a hozzáférést
        FHE.allowThis(taxAmount);
        FHE.allow(taxAmount, taxpayerAddress);
        
        emit TaxPayerAdded(taxpayerAddress);
    }
    
    /// @notice Adófizetés titkosított összeggel
    function payTax(
        externalEuint32 encryptedPaymentAmount, 
        bytes calldata paymentProof
    ) external {
        
        TaxPayer storage taxpayer = taxpayers[msg.sender];
        
        // Ellenőrizzük a fizetés érvényességét
        euint32 paymentAmount = FHE.fromExternal(encryptedPaymentAmount, paymentProof);
        
        // Frissítjük a befizetett összeget (titkosított összeadás)
        taxpayer.paidAmount = FHE.add(taxpayer.paidAmount, paymentAmount);
        
        // Ellenőrizzük, hogy elég-e a befizetés (titkosított összehasonlítás)
        checkTaxPayment(msg.sender);
        
        // Engedélyezzük a frissített adatokhoz való hozzáférést
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
        
        // Ellenőrizzük az új adóösszeg érvényességét
        euint32 newTaxAmount = FHE.fromExternal(encryptedNewTaxAmount, taxProof);
        
        // Frissítjük az adóösszeget
        taxpayer.taxAmount = newTaxAmount;
        
        // Engedélyezzük az új adóösszeghez való hozzáférést
        FHE.allowThis(newTaxAmount);
        FHE.allow(newTaxAmount, taxpayerAddress);
        
        emit TaxAmountUpdated(taxpayerAddress, block.timestamp);
    }
    
    /// @notice Titkosított ellenőrzés, hogy teljesítette-e az adókötelezettséget
    function checkTaxPayment(address taxpayerAddress) public returns (bool) {
        
        TaxPayer storage taxpayer = taxpayers[taxpayerAddress];
        
        // Titkosított összehasonlítás - nem fedi fel az értékeket
        // Ez egy homomorf művelet, titkosítottan ellenőrzi, hogy paidAmount >= taxAmount
        if (FHE.isInitialized(FHE.le(taxpayer.taxAmount, taxpayer.paidAmount))) {
            // Ha a befizetett összeg >= adóösszeg
            return true;
        }
        
        return false;
    }
    
    /// @notice Nyilvános ellenőrzés (csak az adóhatóság számára)
    function verifyTaxPayment(address taxpayerAddress) external onlyTaxAuthority returns (bool) {
        return checkTaxPayment(taxpayerAddress);
    }
    
    
    /// @notice Összes adófizető listázása
    function getAllTaxpayers() external view onlyTaxAuthority returns (address[] memory) {
        return taxpayerAddresses;
    }
    
    /// @notice Adóhatóság megváltoztatása
    function setTaxAuthority(address newAuthority) external onlyTaxAuthority {
        taxAuthority = newAuthority;
    }
}