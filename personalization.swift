
import UIKit
import Foundation

public struct PersonalizationInitResponse: Codable {
    public let ssid: String
    public let seance: String
    public let currency: String
}

class PersonalizationOrderProduct {
    var productId: String
    var quantity: Int

    init(productId: String, quantity: Int) {
        self.productId = productId
        self.quantity = quantity
    }
}

enum PersonalizationError: Error {
    case noShopId
    case noUserSession
    case argumentError
}




// Используем простой URLSession для отправки запросов на сервер https://api.rees46.com
// Никаких индикаторов загрузки и проверки состояния сети не нужно - этим занимается само приложение магазина,
// наша же SDK срабатывает только тогда, когда приложение магазина работает, а оно работает только тогда,
// когда есть интернет.
// Короче, максимально простейшее решение.

class PersonalizationSDK {
    var shopId: String
    var userSession: String
    var userSeance: String

    var userId: String?
    var userEmail: String?
    
    var apiHost = "https://api.rees46.com/"
    
    var sdkReady = false

    
    /**
     Initialize library.
     Run it once on application startup.
     @param shopId String Shop API key
     */
    init(shopId: String) {
        self.shopId = shopId

        // Generage seance
        self.userSeance = UUID().uuidString
        
        // Trying to fetch user session (permanent user ID)
        self.userSession = UserDefaults.standard.string(forKey: "personalization_ssid") ?? ""
        
        // Fetch application/user settings from remote API
        let session = URLSession.shared
        let url = URL(string: "https://" + self.apiHost + "init_script?ssid=" + self.userSession + "&shop_id=" + self.shopId)!

        let task = session.dataTask(with: url, completionHandler: { data, response, error in
            if error != nil {
                // Handle error if needed
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                // Handle error if needed
                return
            }
            
            guard let mime = httpResponse.mimeType, mime == "application/json" else {
                print("Wrong MIME type!")
                return
            }
            
            do {
                
                // TODO: надо как-то распарсить ответ. Структура в PersonalizationInitResponse
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                print(json)
                
                if let ssid = json["ssid"] as? String {
                    print(ssid)
                }
                
            } catch {
                print("JSON error: \(error.localizedDescription)")
                return
            }
           
            
        })

        // Run init request
        task.resume();
        
        
        
        
        
        /**
         TODO:
         Пытаемся достать из локального хранилища идентификатор сессии юзера userSession
         Как только нашли, делаем запрос к https://api.rees46.com/init_script на проверку сессии
         и загрузку настроек магазина. Если из хранилища сессию найти не удалось, делаем запрос с пустой сессией -
         сервер сгенерирует корректный userSession и его нужно будет записать в хранилище.
         Даже если мы вытащили из хранилища userSession, после запроса к серверу нужно сверить его с тем, что пришло
         от сервера и, если отличается, записать в хранилище и установить здесь тот, который пришел оттуда.
         Это можно происходить в случае, если userSession на сервере был удален по разным причинам.
         ↓
         Восстанавливаем или создаем новую сессию и подгружаем с сервера настройки системы
         */
        self.userSession = "TODO"

        // Пример GET-запроса:
        let url = "https://api.rees46.com/init_script?ssid=" + self.userSession + "&shop_id=" + self.shopId + "&seance=" + self.userSeance
        // END OF TODO
        
    
        /**
         TODO:
         Разобрать ответ с настройками магазина от init script и прописать их в настройки SDK
         Типичный ответ (некоторые свойства могут отсутствовать, структура может меняться без согласования, поэтому важно не упасть) в виде JSON:
         
         {
            "ssid":"d701d1af-8cee-48e6-a3ea-e42accd7fc7e",
            "seance":"c08046db-b661-4688-83ae-4d152c13220d",
            "currency":"$",
            "profile":null,
            "email_collector":true,
            "experiments":[],
            "has_email":true,
            "recommendations":true,
            "auto_css_recommender":false,
            "cms":"owndev",
            "snippets":[],
            "subscriptions":{
               "settings":{
                  "enabled":true,
                  "overlay":true,
                  "header":"Be the first informed?",
                  "text":"New arrivals, flash sales and exclusive offers - for our subscribers first!",
                  "button":"Subscribe me!",
                  "agreement":"I agree to get personalized offers from REES46",
                  "successfully":"Awesome! Now our exclusive offers come to your mailbox!",
                  "remote_picture_url":null,
                  "type":0,
                  "timer":90,
                  "pager":5,
                  "cursor":50,
                  "products":null,
                  "products_title":"Вы недавно смотрели",
                  "products_buy":"В корзину",
                  "mobile_enabled":false,
                  "email_enabled":true,
                  "web_push_enabled":true,
                  "public_key":[ 4, 248, 46, 150, 129, 221, 195, 51, 226, 127, 19, 120, 223, 146, 22, 70, 37, 117, 21, 152, 95, 238, 46, 44, 199, 127, 81, 84, 200, 33, 172, 65, 229, 94, 113, 63, 174, 120, 213, 12, 123, 122, 47, 82, 150, 158, 51, 62, 194, 227, 192, 88, 124, 82, 168, 73, 91, 115, 182, 25, 190, 53, 29, 228, 49 ],
                  "default_subscribe":false,
                  "subscribe_type":null,
                  "safari_enabled":false,
                  "safari_id":"",
                  "service_worker":"/push_sw.js",
                  "manifest":"/manifest.json"
               },
               "status":"accepted"
            },
            "search":{
               "enabled":true,
               "landing":"http://demo.rees46.com/search",
               "type":"full",
               "results_title":"Показать все результаты: %query%",
               "settings":{
                  "redirects":{},
                  "suggestions_title":"Suggestions",
                  "categories_title":"Categories",
                  "items_title":"Possible item matches",
                  "show_all_title":"Show all possible matches (%count%): %query%",
                  "last_queries_title":"Недавние запросы",
                  "last_products_title":"Недавно просмотренные товары",
                  "append_to_body":true,
                  "enable_last_queries":true,
                  "enable_old_price":false
               }
            },
            "voice":true,
            "voice_codec":"wav",
            "recone":true
         }
         
         Из всего этого объема данных нас интересуют:
         - ssid - записать в self.userSession
         - seance - должен быть равен self.userSeance
         
         На этом инициализация юзера заканчивается
         
         END OF TODO
         
         */
        
    }
    
    

    /**
     Установить userID из магазина
     @param id String ID пользователя, вполне может быть строковым
     */
//    func setUserId(id: String) {
//        self.userId = id
//        let url = apiHost + "push_attributes"
//        var attributes = [ "id": id ]
//        var params: [String: Any]  = [ "shop_id": self.shopId, "session_id": self.userSession, "attributes": attributes ]
//
//        // TODO отправить на адрес из переменной `url` переменные из `params`. Ответ обрабатывать не нужно.
//    }
//
//
//    /**
//    Установить email пользователя
//    @param email String Email пользователя
//    */
//    func setUserEmail(email: String) {
//        self.userEmail = email
//        let url = apiHost + "push_attributes"
//        var attributes: [String: Any] = [ "email": email ]
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "attributes": attributes ]
//        // TODO отправить на адрес из переменной `url` переменные из `params`. Ответ обрабатывать не нужно.
//    }
//
//
//    /**
//     Отправить событие просмотра пользователем товара
//     */
//    func productViewed(id: String) {
//        let url = apiHost + "/push"
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "item[0]": id, "event": "view" ]
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный POST. Ответ обрабатывать не нужно.
//    }
//
//    /**
//    Отправить событие просмотра пользователем страницы категории
//    */
//    func categoryViewed(id: String) {
//        let url = apiHost + "/push"
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "category_id": id, "event": "category" ]
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный POST. Ответ обрабатывать не нужно.
//    }
//
//
//    /**
//    Отправить событие добавления товара в корзину
//    */
//    func productAddedToCart(id: String) {
//        let url = apiHost + "/push"
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "item[0]": id, "event": "cart" ]
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный POST. Ответ обрабатывать не нужно.
//    }
//
//    /**
//    Отправить событие удаления товара из корзины
//    */
//    func productRemovedFromCart(id: String) {
//        let url = apiHost + "/push"
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "item[0]": id, "event": "remove_from_cart" ]
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный POST. Ответ обрабатывать не нужно.
//    }
//
//    /**
//    Отправить информацию о текущем состоянии корзины
//    */
//    func syncronizeCart(productIds: [String]) {
//        let url = apiHost + "/push"
//        // Важно: здесь productIds передается в запросе не как item=33,34,35, а как item[0]=33&item[1]=34&item[2]=35
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "item": productIds, "event": "cart" ]
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный POST. Ответ обрабатывать не нужно.
//
//    }
//
//    /**
//    Отправить событие оформления пользователем заказа
//    */
//    func orderCreated(orderId: String, total: Double, products: [PersonalizationOrderProduct] ) {
//        let url = apiHost + "/push"
//
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "event": "purchase", "order_id": orderId, "order_price": total, "itemsdata": "TODO" ]
//
//        // Вместо items_data нужно отправить такую структуру:
//        /**
//         item_id[0]: 691
//         amount[0]: 1
//         item_id[1]: 696
//         amount[1]: 1
//         */
//
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный POST. Ответ обрабатывать не нужно.
//
//    }
//
//
//
//    /**
//     Запросить с сервера товарные рекомендации, получить массив рекомендованных товаров и передать его в пользовательскую функцию, которая потом с ними что-то сделает (конкретно отрисует блок рекомендованных товаров)
//     - параметр itemId, его может и не быть
//     */
//    func recommend(blockId: String, itemId: String?) {
//        let url = apiHost + "/recommend"
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "recommender_type": "dynamic", "recommender_code": blockId ]
//        if item_id {
//            params["item_id"] = item_id
//        }
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный GET. Ответ обработать callback-функцией, которую еще нужно прописать в параметры этого метода
//
//        /**
//         Структура ответа API
//         {
//            "recommends":["1013","1012","1025","1023"],
//            "title":"Similar products",
//            "id":170,
//            "html":"..."
//         }
//         В первую очередь нас интересует массив свойства "recommend"
//         */
//    }
//
//    /**
//    Запросить с сервера результат полного поиска, получить массив идентификаторов найденных товаров и передать его в пользовательскую функцию, которая потом с ними что-то сделает (конкретно отрисует результаты поиска)
//    */
//    func search(query: String) {
//        let url = apiHost + "/search"
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "type": "full_search", "search_query": query]
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный GET. Ответ обработать callback-функцией, которую еще нужно прописать в параметры этого метода
//
//        /**
//        Структура ответа API
//        {
//            "search_query":"coat",
//            "products_total":7,
//            "products":[
//                {
//                    "id":"696",
//                    "name":"Leather Rick Evanse Coat",
//                    "url":"...",
//                    "picture":"https://pictures.rees46.com/resize-images/160/357382bf66ac0ce2f1722677c59511/1243396608003932393.jpg",
//                    "price_formatted":"1 166",
//                    "price":1165.83,
//                    "old_price":0.0,
//                    "currency":"$"
//
//                },
//                ...
//            ],
//            "categories":[],
//            "virtual_categories":[],
//            "book_authors":[],
//            "keywords":[],
//            "queries":[],
//            "collections":[],
//            "html":"..."
//
//        }
//        В первую очередь нас интересует массив свойства "products"
//        */
//
//    }
//
//    /**
//    Запросить с сервера результат быстрого поиска/подсказок, получить массив объект разных полезных данных и передать его в пользовательскую функцию, которая потом с ними что-то сделает (конкретно отрисует выпадающий поиск с подходящими товарами, подсказами и т.д.)
//    */
//    func typeahead(query: String) {
//        let url = apiHost + "/search"
//        var params: [String: Any] = [ "shop_id": self.shopId, "session_id": self.userSession, "seance": self.userSeance, "type": "instant_search", "search_query": query]
//        // TODO отправить на адрес из переменной `url` переменные из `params` как обычный GET. Ответ обработать callback-функцией, которую еще нужно прописать в параметры этого метода
//
//        /**
//        Структура ответа API
//
//        {
//            "search_query":"coat",
//            "products_total":7,
//            "products":[
//                {
//                    "id":"696",
//                    "name":"Leather Rick Evanse Coat",
//                    "url":"https://demo.rees46.com/products/696?recommended_by=instant_search\u0026r46_search_query=coat",
//                    "picture":"https://pictures.rees46.com/resize-images/160/357382bf66ac0ce2f1722677c59511/1243396608003932393.jpg",
//                    "price_formatted":"1 166",
//                    "price":1165.83,
//                    "old_price":0.0,
//                    "currency":"$"
//                },
//                ...
//            ],
//            "virtual_categories":[],
//            "book_authors":[],
//            "keywords":[],
//            "queries":[
//                {
//                    "name":"coat",
//                    "url":"http://demo.rees46.com/search?recommended_by=instant_search\u0026r46_search_query=coat"
//
//                },
//                {
//                    "name":"coa",
//                    "url":"http://demo.rees46.com/search?recommended_by=instant_search\u0026r46_search_query=coa"
//                }
//            ],
//            "collections":[]
//
//         }
//
//        В первую очередь нас интересует массивы свойств "products" и "queries"
//        */
//
//    }
    
}




// EXAMPLES


// Создаем объект и инициализируем сессию юзера
var client = PersonalizationSDK(shopId: "357382bf66ac0ce2f1722677c59511")

// Устанавливаем пользовательские данные (могут быть и не установлены)
//client.setUserId(id: "u338")
//client.setUserEmail(email: "mail@example.com")

//
//
//// Отправляем событие "Пользователь посмотрел товар"
//client.productViewed(id: "712")
//
//// Отправляем событие "Пользователь просмотрел категорию"
//client.categoryViewed(id: "50")
//
//// Отправляем событие "Пользователь добавил товар в корзину"
//client.productAddedToCart(id: "712")
//
//// Отправляем событие "Статус корзины"
//client.syncronizeCart(productIds: ["712", "720", "1016"])
//
//// Отправляем событие "Пользователь убрал товар из корзины"
//client.productRemovedFromCart(id: "712")
//
//// Отправляем событие "Пользователь оформил заказ"
//let purchasedProducts = [
//    PersonalizationOrderProduct(productId: "712", quantity: 2),
//    PersonalizationOrderProduct(productId: "720", quantity: 1)
//]
//client.orderCreated(orderId: "ID33", total: 3349.23, products: purchasedProducts)
//
//
//// Запросить товарные рекомендации и передать в callback функцию
//client.recommend(blockId: "977cb67194a72fdc7b424f49d69a862d", itemId: "696", ... как-то указать callback-функцию ...)
//
//// Запросить поисковые подсказки
//client.typeahead(query: "coa", ... как-то указать callback-функцию ...)
//
//// Выполнить полный поиск
//client.search(query: "coat", ... как-то указать callback-функцию ...)
