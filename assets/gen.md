Je voudrais que tu me génère un schéma expliquant ce processus :

Un generator de messages vers topics :
- orders.clients
- orders.commands
- orders.lines

Prise en charge par un RizingWave 

1 - C'est messages sont consommer par les sources kafka :
* src_order_clients
* src_order_lines
* src_orders

2 - Création de vues matérialisées :
* mv_order_items
* mv_customers_json
* mv_order_360
* mv_orders_par_status

3 - Création des sinks Opensearch
* sink_order_360, index  ==> orders_360
* sink_orders_par_status ==> orders_par_status