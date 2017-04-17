
'use strict;'
var HTTP_SERVER = process.env.HTTP_SERVER || 'localhost';
var HTTP_PORT   = process.env.HTTP_PORT || '8080';

var webdriver = require('selenium-webdriver'),
    By = webdriver.By,
    until = webdriver.until;


var driver = new webdriver.Builder()
                          .forBrowser('firefox')
                          .build();

function setSangerUser(driver, username) {
  var TestCookie = 'TestAuthCookie';
  driver.manage().deleteCookie(TestCookie);
  if(username !== 'undefined' && username != null) {
    driver.manage().addCookie(TestCookie, username);
  }
}

function changeOutcome(driver, webdriver, lane, outcome) {
  driver.findElement(webdriver.By.xpath('//*[@id="mqc_lane' + lane + '"]/label[' + outcome + ']')).click(); 
}

var defaultValue = {
  title : 'NPG SeqQC v0: Results for run 18335 (current run status: qc in progress, taken by jmtc)',
  url   : 'http://' + HTTP_SERVER + ':' + HTTP_PORT + '/checks/runs/18335',
}
var j = 'jmtc', e = 'en3';

driver.get(defaultValue.url);
driver.sleep(3000);

setSangerUser(driver, j);
driver.get(defaultValue.url);
driver.wait(function () {
  return driver.isElementPresent(webdriver.By.name("radios_18335_8"));
}, 10000);
for (var i = 0; i < 8; i+=2) {
  changeOutcome(driver, webdriver, i + 1, 1); //Accepted preliminary
}
driver.sleep(3000);
//Check plots were generated
driver.executeScript("javascript:window.scrollBy(0,1500)");
driver.sleep(1000);

setSangerUser(driver, e);
driver.get(defaultValue.url);
driver.wait(until.titleIs(defaultValue.title), 10000);
driver.sleep(2000);

setSangerUser(driver, j);
driver.get(defaultValue.url);
driver.wait(function () {
  return driver.isElementPresent(webdriver.By.name("radios_18335_8"));
}, 10000);
for (var i = 0; i < 8; i+=2) {
  changeOutcome(driver, webdriver, i + 1, 3); //Rejected preliminary
}
driver.sleep(3000);
//Check plots were generated
driver.executeScript("javascript:window.scrollBy(0,1500)");
driver.sleep(1000);

setSangerUser(driver, e);
driver.get(defaultValue.url);
driver.wait(until.titleIs(defaultValue.title), 10000);
driver.sleep(2000);

setSangerUser(driver, j);
driver.get(defaultValue.url);
driver.wait(function () {
  return driver.isElementPresent(webdriver.By.name("radios_18335_8"));
}, 10000);
for (var i = 0; i < 8; i+=2) {
  changeOutcome(driver, webdriver, i + 1, 2); //Undecided
}
driver.sleep(3000);
//Check plots were generated
driver.executeScript("javascript:window.scrollBy(0,1500)");
driver.sleep(1000);

setSangerUser(driver, e);
driver.get(defaultValue.url);
driver.wait(until.titleIs(defaultValue.title), 10000);
driver.sleep(2000);

driver.quit();

