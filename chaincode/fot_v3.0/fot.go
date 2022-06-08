package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/go-playground/validator/v10"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing an Product
type SmartContract struct {
	contractapi.Contract
}

// Product Structure
type Product struct {
	UniqueID         string `validate:"required"`
	OrderID          string `validate:"required"`
	ProductID        string `validate:"required"`
	SKUID            string `validate:"required"`
	ProductName      string `validate:"required"`
	SellerName       string `validate:"required"`
	CustomerName     string `validate:"required"`
	ScanType         string `validate:"required"`
	DateTime         string `validate:"required"`
	Location         string `validate:"required"`
	MetaData         string `validate:"required"`
	ReferenceOrder   string `validate:"required"`
	ProductReference string `validate:"required"`
}

var validate *validator.Validate

func validateProductStruct(product Product) error {

	validate = validator.New()
	err := validate.Struct(product)
	if err != nil {
		return err
	}

	return nil

}

// Create Product issues a new Product to the world state with given details.
func (s *SmartContract) InsertProductRecords(ctx contractapi.TransactionContextInterface, ProductData string) (string, error) {

	if len(strings.TrimSpace(ProductData)) == 0 {
		return "", fmt.Errorf("Please pass the correct Product data. The Product Data is Empty or Contains only Whitespaces")
	}

	var product Product
	err := json.Unmarshal([]byte(ProductData), &product)
	if err != nil {
		return "", fmt.Errorf("Failed while unmarshling Product Data. The Error is: %s. Please check for Product JSON Data", err.Error())
	}

	//Product Data Validation
	err = validateProductStruct(product)
	if err != nil {
		return "", fmt.Errorf(err.Error())
	}

	// Check whether given UniqueID Already Exists or Not.
	exists, err := s.ProductExists(ctx, product.UniqueID)
	if err != nil {
		return "", err
	}
	if exists {
		return "", fmt.Errorf("The Given UniqueID: %s already Exists. Please try with someother UniqueID.", product.UniqueID)
	}

	productAsBytes, err := json.Marshal(product)
	if err != nil {
		return "", fmt.Errorf("Failed while marshling Product Data. The Error is:  %s", err.Error())
	}

	return ctx.GetStub().GetTxID(), ctx.GetStub().PutState(product.UniqueID, productAsBytes)

}

// ReadProduct returns the product stored in the world state with given id.
func (s *SmartContract) GetProductByUniqueID(ctx contractapi.TransactionContextInterface, UniqueID string) (*Product, error) {
	if len(strings.TrimSpace(UniqueID)) == 0 {
		return nil, fmt.Errorf("Please pass the correct Product UniqueID. The Product UniqueID is Empty or contains only whitespaces.")
	}

	productAsBytes, err := ctx.GetStub().GetState(UniqueID)

	if err != nil {
		return nil, fmt.Errorf("Product Fetch Failed for the UniqueID: %s. The Error is %s", UniqueID, err.Error())
	}

	if productAsBytes == nil {
		return nil, fmt.Errorf("The UniqueID: %s does not exist", UniqueID)
	}

	var product Product
	err = json.Unmarshal(productAsBytes, &product)
	if err != nil {
		return nil, fmt.Errorf("Failed while unmarshling Product Data. The Error is: %s", err.Error())
	}

	return &product, nil

}

func (s *SmartContract) GetProductForQuery(ctx contractapi.TransactionContextInterface, queryString string) ([]Product, error) {

	isValidJson := json.Valid([]byte(queryString))
	if !isValidJson {
		return nil, fmt.Errorf("Invalid JSON")
	}

	queryResults, err := s.getQueryResultForQueryString(ctx, queryString)

	if err != nil {
		return nil, fmt.Errorf("Failed to read from world state. %s", err.Error())
	}

	return queryResults, nil

}

func (s *SmartContract) getQueryResultForQueryString(ctx contractapi.TransactionContextInterface, queryString string) ([]Product, error) {

	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	results := []Product{}

	for resultsIterator.HasNext() {
		response, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		newProduct := new(Product)

		err = json.Unmarshal(response.Value, newProduct)
		if err != nil {
			return nil, err
		}

		results = append(results, *newProduct)
	}
	return results, nil
}

// UpdateProduct updates an existing product in the world state with provided parameters.
func (s *SmartContract) UpdateProduct(ctx contractapi.TransactionContextInterface, uniqueID string, orderID string, productID string, skuid string, productname string, sellername string, customername string, scantype string, datetime string, location string, metadata string, referenceorder string, productreference string) (string, error) {

	if len(strings.TrimSpace(uniqueID)) == 0 {

		return "", fmt.Errorf("Please pass the correct Product UniqueID. The Product UniqueID is Empty or contains only whitespaces.")
	}

	// Check whether given UniqueID Already Exists or Not.
	exists, err := s.ProductExists(ctx, uniqueID)
	if err != nil {
		return "", err
	}
	if !exists {
		return "", fmt.Errorf("The Given UniqueID: %s not Exists. Please try with correct existing UniqueID.", uniqueID)
	}

	// overwriting original product with new product
	product := Product{
		UniqueID:         uniqueID,
		OrderID:          orderID,
		ProductID:        productID,
		SKUID:            skuid,
		ProductName:      productname,
		SellerName:       sellername,
		CustomerName:     customername,
		ScanType:         scantype,
		DateTime:         datetime,
		Location:         location,
		MetaData:         metadata,
		ReferenceOrder:   referenceorder,
		ProductReference: productreference,
	}

	productAsBytes, err := json.Marshal(product)
	if err != nil {
		return "", fmt.Errorf("Failed to marshal Product Data. The Error is: %s", err.Error())
	}
	return ctx.GetStub().GetTxID(), ctx.GetStub().PutState(product.UniqueID, productAsBytes)
}

func (s *SmartContract) DeleteProductByuniqueID(ctx contractapi.TransactionContextInterface, uniqueID string) (string, error) {

	if len(strings.TrimSpace(uniqueID)) == 0 {
		return "", fmt.Errorf("Please pass the correct Product UniqueID. The Product UniqueID is Empty or contains only whitespaces.")
	}

	// Check whether given UniqueID Already Exists or Not.
	exists, err := s.ProductExists(ctx, uniqueID)
	if err != nil {
		return "", err
	}
	if !exists {
		return "", fmt.Errorf("The Given UniqueID: %s not Exists. Please try with correct existing UniqueID.", uniqueID)
	}
	return ctx.GetStub().GetTxID(), ctx.GetStub().DelState(uniqueID)
}

// AssetExists returns true when asset with given ID exists in world state
func (s *SmartContract) ProductExists(ctx contractapi.TransactionContextInterface, uniqueID string) (bool, error) {

	if len(strings.TrimSpace(uniqueID)) == 0 {
		return false, fmt.Errorf("Please pass the correct Product UniqueID. The Product UniqueID is Empty or contains only whitespaces.")
	}

	productJSON, err := ctx.GetStub().GetState(uniqueID)
	if err != nil {
		return false, fmt.Errorf("Product Exists Check Failed for the given UniqueID. The Error is: %v", err)
	}

	return productJSON != nil, nil
}

func (s *SmartContract) GetHistoryForProduct(ctx contractapi.TransactionContextInterface, uniqueID string) (string, error) {

	if len(strings.TrimSpace(uniqueID)) == 0 {
		return "", fmt.Errorf("Please pass the correct Product UniqueID. The Product UniqueID is Empty or contains only whitespaces.")
	}

	resultsIterator, err := ctx.GetStub().GetHistoryForKey(uniqueID)
	if err != nil {
		return "", fmt.Errorf(err.Error())
	}
	defer resultsIterator.Close()

	var buffer bytes.Buffer
	buffer.WriteString("[")

	bArrayMemberAlreadyWritten := false
	for resultsIterator.HasNext() {
		response, err := resultsIterator.Next()
		if err != nil {
			return "", fmt.Errorf(err.Error())
		}
		if bArrayMemberAlreadyWritten == true {
			buffer.WriteString(",")
		}
		buffer.WriteString("{\"TxId\":")
		buffer.WriteString("\"")
		buffer.WriteString(response.TxId)
		buffer.WriteString("\"")

		buffer.WriteString(", \"Value\":")
		if response.IsDelete {
			buffer.WriteString("null")
		} else {
			buffer.WriteString(string(response.Value))
		}

		buffer.WriteString(", \"Timestamp\":")
		buffer.WriteString("\"")
		buffer.WriteString(time.Unix(response.Timestamp.Seconds, int64(response.Timestamp.Nanos)).String())
		buffer.WriteString("\"")

		buffer.WriteString(", \"IsDelete\":")
		buffer.WriteString("\"")
		buffer.WriteString(strconv.FormatBool(response.IsDelete))
		buffer.WriteString("\"")

		buffer.WriteString("}")
		bArrayMemberAlreadyWritten = true
	}
	buffer.WriteString("]")

	return string(buffer.Bytes()), nil
}

func main() {

	chaincode, err := contractapi.NewChaincode(new(SmartContract))

	if err != nil {
		fmt.Printf("Error creating FOT chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting FOT chaincode: %s", err.Error())
	}

}
