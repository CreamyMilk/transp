package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
)

type Messo struct {
	Subid     string `json:"subscriptionid"`
	TimeStamp string `json:"messageTimestamp"`
	Thread    string `json:"thread"`
	Phone     string `json:"phoneNumber"`
	Subject   string `json:"MessageSubject"`
	Text      string `json:"messagetxt"`
}

type MessageRequest struct {
	MessageDump []Messo `json:"messageDump"`
}

const (
	phoneRegx  = ` (0|254)\d{9} `
	timeRegx   = `( |[0,1])[0-9]:([0-9][0-9]) (AM|PM|am|pm)`
	dateRegx   = ` ([0-9]{1,2}\/[0-9]{1,2}\/[0-9]{2,4}) `
	amountRegx = ` (KSH|Ksh|ksh)[0-9]+\.[0-9][0-9]( |.)`
	transCost  = ` Transaction cost, (Ksh|KSH|ksh)([0-9]+.[0-9][0-9])`
	transID    = `([A-Za-z0-9]*) (Confirmed|confirmed)\.`
	newBalance = ` (New M-PESA balance is )(KSH|Ksh|ksh)[0-9]+\.[0-9][0-9]( |.)`
)

const (
	//Look into remove banking conflicts
	typeSendingMoneyTo        = `sent to [A-Za-z ]*` + phoneRegx
	typeReceivedMoney         = `You have received `
	typeBuyAirtimeSelf        = `You bought` + amountRegx + `of airtime `
	typeBuyAirtimeOtherPerson = `You bought` + amountRegx + `of airtime for`
	typeBuyGoods              = `paid to`
	typePayBill               = `for account`
	typeDeposit               = `[Gg]ive`
	typeWithdraw              = `[Ww]ithdraw`
	typeReversal              = `reversed `
)

func (d *MessageRequest) GetType(filename string, pattern string) error {
	f, err := os.OpenFile(filename, os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer f.Close()

	for _, m := range d.MessageDump {
		data := fmt.Sprintf("%s\r\n", m.Text)
		found, err := regexp.Match(pattern, []byte(m.Text))
		if err != nil {
			log.Println(err)
		}
		if found {
			_, err := f.Write([]byte(data))
			if err != nil {
				return err
			}
		}
	}
	return nil
}

func (d *MessageRequest) CSVV() error {
	f, err := os.OpenFile("results.csv", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer f.Close()

	for _, m := range d.MessageDump {
		data := fmt.Sprintf("%s\r\n", m.Text)
		//parse(m.Text)
		parse(m.Text)
		_, err := f.Write([]byte(data))
		if err != nil {
			return err
		}
	}
	return nil
}

func parse(str string) {
	re := regexp.MustCompile(newBalance)
	words := re.FindAll([]byte(str), -1)
	for _, number := range words {
		fmt.Printf("%s\n", number)
	}
}

func dataHandler(w http.ResponseWriter, r *http.Request) {
	var data MessageRequest
	err := json.NewDecoder(r.Body).Decode(&data)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	go data.GetType("sending.csv", typeSendingMoneyTo)
	go data.GetType("recievied.csv", typeReceivedMoney)
	go data.GetType("buyMyAitime.csv", typeBuyAirtimeSelf)
	go data.GetType("otherGuyAirtime.csv", typeBuyAirtimeOtherPerson)
	go data.GetType("buygoods.csv", typeBuyGoods)
	go data.GetType("paybill.csv", typePayBill)
	go data.GetType("deposit.csv", typeDeposit)
	go data.GetType("withdraw.csv", typeWithdraw)
	go data.GetType("reversals.csv", typeReversal)

	fmt.Println("We wrote some data here")
	fmt.Fprintf(w, "hello worldo")
}

func main() {
	fmt.Println("Please send some data to localhost:3000")
	http.HandleFunc("/data", dataHandler)
	http.ListenAndServe(":3000", nil)
}
