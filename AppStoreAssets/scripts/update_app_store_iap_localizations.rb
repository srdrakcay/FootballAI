require "spaceship"

USER = "srdrakcay25@gmail.com"
TEAM_ID = "127833330"
APP_ID = "6791553742"

PRODUCTS = {
  "6791565835" => "footballai_credits_5",
  "6791575552" => "footballai_credits_10"
}.freeze

client = Spaceship::ConnectAPI.login(
  USER,
  nil,
  use_portal: false,
  tunes_team_id: TEAM_ID
).tunes_request_client

PRODUCTS.each do |purchase_id, product_id|
  folder = File.expand_path("../iap/#{product_id}", __dir__)
  desired = {}

  Dir.glob(File.join(folder, "*.txt")).sort.each do |path|
    locale = File.basename(path, ".txt")
    name, description = File.read(path, encoding: "UTF-8").strip.split("|", 2)
    desired[locale] = { name: name, description: description }
  end

  response = client.get("v2/inAppPurchases/#{purchase_id}/inAppPurchaseLocalizations")
  existing = response.body.fetch("data").to_h do |item|
    [item.fetch("attributes").fetch("locale"), item]
  end

  desired.each do |locale, copy|
    attributes = {
      locale: locale,
      name: copy.fetch(:name),
      description: copy.fetch(:description)
    }

    if existing.key?(locale)
      localization_id = existing.fetch(locale).fetch("id")
      client.patch(
        "v1/inAppPurchaseLocalizations/#{localization_id}",
        data: {
          type: "inAppPurchaseLocalizations",
          id: localization_id,
          attributes: attributes.slice(:name, :description)
        }
      )
      puts "#{product_id}|#{locale}|updated"
    else
      client.post(
        "v1/inAppPurchaseLocalizations",
        data: {
          type: "inAppPurchaseLocalizations",
          attributes: attributes,
          relationships: {
            inAppPurchaseV2: {
              data: { type: "inAppPurchases", id: purchase_id }
            }
          }
        }
      )
      puts "#{product_id}|#{locale}|created"
    end
  end
end
