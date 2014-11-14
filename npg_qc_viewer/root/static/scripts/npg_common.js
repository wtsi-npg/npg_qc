/*
* Author:        Marina Gourtovaia
*
* Copyright (C) 2014 Genome Research Ltd.
*
* This file is part of NPG software.
*
* NPG is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/************************************************************************************
*
* A collection of commonly used JavaScript functions.
*
************************************************************************************/

/*
* Returns the base URI for NPG and Sequencescape web requests
* The first attribute is the service owner string(npg or st),
* the default is st. The second attribute is live or dev, the default is live.
*/
function service_uri(service_owner) {
  if (service_owner == "npg") {
    return npg_url;
  }
  return lims_api_url;
}

/*
* Returns the base URI for a page
*/
function base_uri() {
  var full_uri = location.href;
  var path = location.pathname;
  if (path) {
      return full_uri.substr(0, full_uri.length - path.length);
  }
  return full_uri;
}
