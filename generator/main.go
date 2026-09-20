// Générateur de données de démo pour simulation de commandes
//
// Produit un flux continu d'événements métier dans les topics Redpanda :
//   - orders.commands   (ordre complet, document racine)
//   - orders.clients    (métadonnées client)
//   - orders.lines      (lignes de commande)
//
// Les événements sont cohérents entre eux : un ordre référence un client
// et contient plusieurs lignes publiées aussi séparément.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
)

var (
	redpandaBootstrap = envOr("REDPANDA_BOOTSTRAP", "redpanda:29092")
	messageIntervalMs = envInt("MESSAGE_INTERVAL_MS", 500)
	topicPrefix       = envOr("TOPIC_PREFIX", "orders")
	topicCommands     = topicPrefix + ".commands"
	topicClients      = topicPrefix + ".clients"
	topicOrderLines   = topicPrefix + ".lines"
)

var (
	noms       = []string{"Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau", "Garcia", "Fournier"}
	villes     = []string{"Paris", "Lyon", "Marseille", "Toulouse", "Nice", "Nantes", "Strasbourg", "Bordeaux", "Lille", "Rennes"}
	products   = []string{"Clavier Mécanique RGB", "Souris Sans Fil", "Casque Gamer", "Écran 24\"", "Station Docking", "SSD 1TB", "Webcam HD"}
	categories = []string{"Informatique", "Bureau", "Audio", "Accessoires"}
)

// Client est un client d'assurance.
type Customer struct {
	CustomerID      string `json:"customer_id"`
	Name            string `json:"name"`
	Tier            string `json:"tier"`
	ShippingAddress struct {
		Street     string `json:"street"`
		City       string `json:"city"`
		PostalCode string `json:"postal_code"`
		Country    string `json:"country"`
	} `json:"shipping_address"`
}

type Item struct {
	ItemID      string  `json:"item_id"`
	ProductName string  `json:"product_name"`
	Category    string  `json:"category"`
	Quantity    int     `json:"quantity"`
	UnitPrice   float64 `json:"unit_price"`
}

type PaymentSummary struct {
	Currency    string  `json:"currency"`
	Subtotal    float64 `json:"subtotal"`
	TaxAmount   float64 `json:"tax_amount"`
	TotalAmount float64 `json:"total_amount"`
}

type Order struct {
	OrderID        string         `json:"order_id"`
	Status         string         `json:"status"`
	CreatedAt      string         `json:"created_at"`
	Customer       Customer       `json:"customer"`
	Items          []Item         `json:"items"`
	PaymentSummary PaymentSummary `json:"payment_summary"`
}

// BusinessState maintient l'état en mémoire pour générer des événements cohérents.
type BusinessState struct {
	nextID        int
	customers     []Customer
	referenceDate time.Time
}

func newBusinessState() *BusinessState {
	return &BusinessState{
		nextID:        1,
		referenceDate: time.Now(),
	}
}

// randDate renvoie une date aléatoire comprise entre maintenant et
// (now - daysBack), au format ISO 8601 sans fuseau.
func (s *BusinessState) randDate(daysBack int) string {
	offset := time.Duration(rand.Intn(daysBack*24*60*60+1)) * time.Second
	d := s.referenceDate.Add(-offset)
	return d.Format("2006-01-02T15:04:05.000000")
}
func (s *BusinessState) emitCustomer() Customer {
	id := fmt.Sprintf("CUST-%d", s.nextID)
	s.nextID++
	c := Customer{
		CustomerID: id,
		Name:       fmt.Sprintf("%s %s", pick(noms), pick(noms)),
		Tier:       "GOLD",
	}
	c.ShippingAddress.Street = fmt.Sprintf("%d rue de la Paix", rand.Intn(200)+1)
	c.ShippingAddress.City = pick(villes)
	c.ShippingAddress.PostalCode = fmt.Sprintf("%05d", 75000+rand.Intn(9000))
	c.ShippingAddress.Country = "FR"
	s.customers = append(s.customers, c)
	return c
}

func (s *BusinessState) emitOrder() Order {
	orderID := fmt.Sprintf("ORD-2026-%04d", s.nextID)
	s.nextID++
	// Pick or create a customer sometimes
	var cust Customer
	if len(s.customers) == 0 || rand.Float64() < 0.2 {
		cust = s.emitCustomer()
	} else {
		cust = s.customers[rand.Intn(len(s.customers))]
	}

	// Items
	nItems := 1 + rand.Intn(4)
	var items []Item
	subtotal := 0.0
	for i := 0; i < nItems; i++ {
		pid := fmt.Sprintf("ITM-%03d", rand.Intn(999)+1)
		q := 1 + rand.Intn(3)
		price := round2(10 + rand.Float64()*320)
		itm := Item{
			ItemID:      pid,
			ProductName: pick(products),
			Category:    pick(categories),
			Quantity:    q,
			UnitPrice:   price,
		}
		items = append(items, itm)
		subtotal += float64(q) * price
	}
	tax := round2(subtotal * 0.2)
	total := round2(subtotal + tax)

	order := Order{
		OrderID:   orderID,
		Status:    "COMPLETED",
		CreatedAt: s.randDate(7),
		Customer:  cust,
		Items:     items,
		PaymentSummary: PaymentSummary{
			Currency:    "EUR",
			Subtotal:    round2(subtotal),
			TaxAmount:   tax,
			TotalAmount: total,
		},
	}
	return order
}

func main() {
	log.Printf("[generator] Bootstrap: %s, interval: %dms", redpandaBootstrap, messageIntervalMs)

	client, err := kgo.NewClient(
		kgo.SeedBrokers(strings.Split(redpandaBootstrap, ",")...),
		kgo.ProducerLinger(10*time.Millisecond),
		kgo.RequiredAcks(kgo.AllISRAcks()),
	)
	if err != nil {
		log.Fatalf("impossible de créer le producer: %v", err)
	}
	defer client.Close()

	// Attend que le broker soit joignable.
	var ok bool
	for attempt := 1; attempt <= 30; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		err := client.Ping(ctx)
		cancel()
		if err == nil {
			log.Printf("[generator] Connexion à Redpanda OK: %s", redpandaBootstrap)
			ok = true
			break
		}
		log.Printf("[generator] broker pas prêt (%d/30): %v", attempt, err)
		time.Sleep(3 * time.Second)
	}
	if !ok {
		log.Fatal("Redpanda injoignable après plusieurs tentatives")
	}

	state := newBusinessState()

	publish := func(topic string, key string, value any) {
		payload, err := json.Marshal(value)
		if err != nil {
			log.Printf("[generator] encodage JSON impossible: %v", err)
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := client.ProduceSync(ctx, &kgo.Record{
			Topic: topic,
			Key:   []byte(key),
			Value: payload,
		}).FirstErr(); err != nil {
			log.Printf("[generator] erreur d'envoi vers %s: %v", topic, err)
		}
	}

	customerKey := func(id string) string { return id }
	orderKey := func(id string) string { return id }

	// Démarrage : peuple quelques clients et commandes pour démarrage rapide.
	for i := 0; i < 20; i++ {
		c := state.emitCustomer()
		publish(topicClients, customerKey(c.CustomerID), c)
	}
	for i := 0; i < 50; i++ {
		o := state.emitOrder()
		publish(topicCommands, orderKey(o.OrderID), o)
		for _, itm := range o.Items {
			lineEv := map[string]any{"order_id": o.OrderID, "item": itm}
			publish(topicOrderLines, orderKey(o.OrderID), lineEv)
		}
	}
	log.Println("[generator] Données initiales envoyées. Production continue...")

	// Boucle de production continue.
	ticker := time.NewTicker(time.Duration(messageIntervalMs) * time.Millisecond)
	defer ticker.Stop()
	for range ticker.C {
		r := rand.Intn(100)
		switch {
		case r < 15:
			c := state.emitCustomer()
			publish(topicClients, customerKey(c.CustomerID), c)
		default:
			o := state.emitOrder()
			publish(topicCommands, orderKey(o.OrderID), o)
			for _, itm := range o.Items {
				lineEv := map[string]any{"order_id": o.OrderID, "item": itm}
				publish(topicOrderLines, orderKey(o.OrderID), lineEv)
			}
		}
	}
}

func pick(list []string) string { return list[rand.Intn(len(list))] }

func randFloat(lo, hi float64) float64 { return lo + rand.Float64()*(hi-lo) }

func round2(v float64) float64 { return math.Round(v*100) / 100 }

func envOr(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if v, ok := os.LookupEnv(key); ok {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}
