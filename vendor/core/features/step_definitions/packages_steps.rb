When /^I enter the sip name into the box$/ do
  query = packages.map { |p| Package.get(p.split('/').last).sip.name }.join ' '
  fill_in "search", :with => query
end

When /^I enter the package ids? into the box$/ do
  query = packages.map { |p| Package.get(p.split('/').last).id }.join ' '
  fill_in "search", :with => query
end

When /^I enter one package id and one sip id into the box$/ do
  raise "need at least two sips" if packages.size < 2

  qa = []

  packages.each_with_index do |u, ix|
    p = Package.get u.split('/').last

    term = if ix % 2
             p.id
           else
             p.sip.name
           end

    qa << term
  end

  query = qa.join ' '

  fill_in "search", :with => query
end

Then /^I should see the packages? in the results$/ do

  packages.each do |s|
    last_response.should have_selector("td a[href='/package/#{last_package_id}']", :content => last_package_id)
  end

end

Then /^I should see that package in the results$/ do
  id = last_package ? last_package_id : Package.first.id
  last_response.should have_selector("td a[href='/package/#{id}']", :content => id)
end

Then /^I should not see the package in the results$/ do
  id = last_package ? last_package_id : Package.first.id
  last_response.should_not have_selector("td a[href='/package/#{id}']", :content => id)
end

Then /^I should see a "([^"]*)" heading$/ do |heading|
  doc = Nokogiri::HTML last_response.body
  rules = (1..3).map { |n| "h#{n}:contains('#{heading}')"}
  matches = doc.css *rules
  matches.should_not be_empty
end

Then /^I should see the following columns:$/ do |table|

  table.headers.each do |h|
    last_response.should have_selector("th:contains('#{h}')")
  end

end

Then /^the package column should link to a package$/ do
  last_response.should have_selector("td a[href*='/package/']")
end
