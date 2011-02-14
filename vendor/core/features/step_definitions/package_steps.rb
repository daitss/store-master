When /^I goto its package page$/ do
  visit last_package
end

When /^I goto its ingest report$/ do
  visit last_package + "/ingest_report"
end

Then /^in the submission summary I should see the (name|account|project)$/ do |field|
  last_response.should have_selector("th:contains('#{field}')")
end

Then /^in the jobs summary I should see an ingest wip$/ do
  last_response.should have_selector("a[href='/workspace/#{last_package_id}']", :content => 'ingesting')
end

Then /^in the events I should see a "([^\"]*)" event with "([^"]*)" in the notes$/ do |event, notes|
  pending notes if notes =~ %r{\?$}
  last_response.should have_selector(%Q{td:contains("#{event}")})
  last_response.should have_selector(%Q{td:contains("#{notes}")})
end

Then /^in the events I should not see a "([^\"]*)" event with "([^"]*)" in the notes$/ do |event, notes|
  pending notes if notes =~ %r{\?$}
  last_response.should have_selector("td:contains('#{event}')")
  last_response.should_not have_selector("td:contains('#{notes}')")
end

Then /^in the aip section I should see (copy url|copy size|copy sha1|number of datafiles)$/ do |field|
  last_response.should have_selector("th:contains('#{field}') + td")
end

Then /^in the aip section I should see a link to the descriptor$/ do
  last_response.should have_selector("a[href='/package/#{last_package_id}/descriptor']")
end

Then /^in the jobs summary I should see a stashed ingest wip in "([^\"]*)"$/ do |bin_name|
  bin = Daitss.archive.stashspace.find { |b| b.name == bin_name }
  bin.should_not be_nil
  last_response.should have_selector("a[href='/stashspace/#{bin.id}/#{last_package_id}']", :content => 'stashed')
end

Then /^in the jobs summary I should see that no jobs are pending$/ do
  Then %Q(the response contains "archived")
end

Then /^there (should not|should) be an "([^"]*)" event$/ do |presence, event|

  if presence == 'should'
    last_response.should have_selector("td", :content => event)
  else
    last_response.should_not have_selector("td", :content => event)
  end

end

When /^I choose request type "([^"]*)"$/ do |type|

  within "#request" do
    select type, :from => 'type'
  end

end

When /^I fill in request note with "([^"]*)"$/ do |note|

  within "#request" do
    fill_in 'note', :with => note
  end

end

Then /^I should see a ([^"]*) request$/ do |type|
  When %Q(I goto its package page)
  last_response.should have_selector("#request table tr td", :content => type)
end

Then /^I should see a ([^"]*) request with note "([^"]*)" and authorized "(yes|no)"$/ do |type, note, auth|
  When %Q(I goto its package page)
  last_response.should have_selector("#request table tr td", :content => type)
  last_response.should have_selector("#request table tr td", :content => note)
  last_response.should have_selector("#request table tr td", :content => auth)
end

Then /^I should see a ([^"]*) request with status "([^"]*)"$/ do |type, status|
  When %Q(I goto its package page)
  last_response.should have_selector("#request table tr td", :content => type)
  last_response.should have_selector("#request table tr td", :content => status)
end

Then /^there should be a request heading$/ do
  last_response.should have_selector("#request h2", :content => 'requests')
end

Then /^there should be a request form$/ do
  last_response.should have_selector("#request")
end

Then /^there should (be|not be) a request table$/ do |cond|

  if cond == 'be'
    last_response.should have_selector("#request table")
  else
    last_response.should_not have_selector("#request table")
  end

end

Given /^a ([^"]*) request$/ do |type|
  visit last_package
  And %Q(I choose request type "#{type}")
  And %Q(I press "Request")
 Then %Q(I should see a #{type} request)
end

When /^I press "([^"]*)" for the request$/ do |button|

  within "#request table tr td form" do
    click_button button
  end

end

Then /^I should not see the request$/ do
  last_response.should_not have_selector("#request table tr")
end

# ensure that response can be parsed as xml and contains the IEID
# TODO: thorough ingest report testing, checking contents against database
Then /^the response should contain a valid ingest report$/ do
  last_response.body.should_not be_nil

  doc = Nokogiri::XML last_response.body
  ieid = File.basename last_package
  last_response.body.should =~ /#{ieid}/
end

Then /^the body should be mets xml$/ do
  doc = Nokogiri::XML last_response.body
  doc.root.name.should == 'mets'
  doc.root.namespace.href.should == "http://www.loc.gov/METS/"
end

Then /^there should be link to a dip$/ do
  last_response.should have_selector("a[href='/package/#{last_package_id}/dip/#{last_package_id}-0.tar']")
end

Then /^clicking the dip link downloads the tarball$/ do
  click_link "#{last_package_id}-0.tar"
  last_response.should be_ok
end

Then /^there should be a report delivery record$/ do
  ReportDelivery.first(:package_id => File.basename(last_package)).should_not be_nil
end
