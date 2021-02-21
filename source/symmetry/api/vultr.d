module symmetry.api.vultr;
import std.stdio;
import std.json;
import std.net.curl;
import std.exception : enforce,assumeUnique;
import std.conv:to;
import std.algorithm:countUntil,map,each;
import std.traits:EnumMembers;
import std.array:array,appender;
import std.format:format;
import std.variant:Algebraic;
import symmetry.helper.prettyjson;

/**
    Implemented in the D Programming Language 2015 by Laeeth Isharc and Kaleidic Associates
    Boost Licensed
    Use at your own risk - this is not tested at all and if you end up deleting all your
    instances and creating 10,000 pricey new ones then it will not be my fault
*/


string joinUrl(string url, string endpoint)
{
    enforce(url.length>0, "broken url");
    if (url[$-1]=='/')
        url=url[0..$-1];
    return url~"/"~endpoint;
}
/**
    auto __str__(self):
        return b"<{:s} at {:#x}>".format(type(self).__name__, id(self))

    auto __unicode__(self):
        return "<{:s} at {:#x}>".format(type(self).__name__, id(self))
*/

struct VultrAPI
{
    string endpoint = "https://api.vultr.com/v1";
    string token;

    this(string token)
    {
        this.token=token;
    }
    this(string endpoint, string token)
    {
        this.endpoint=endpoint;
        this.token=token;
    }
}

JSONValue request(VultrAPI api, string url, HTTP.Method method=HTTP.Method.get, JSONValue params=JSONValue(null))
{
    enforce(api.token.length>0,"no token provided");
    url=api.endpoint.joinUrl(url);
    auto client=HTTP(url);
    client.addRequestHeader("API-Key", api.token);
    auto response=appender!(ubyte[]);
    client.method=method;
    switch(method) with(HTTP.Method)
    {
        case del:
            client.setPostData(cast(void[])params.toString,"application/x-www-form-urlencoded");
            break;
        case get,head:
            client.setPostData(cast(void[])params.toString,"application/json");
            break;
        default:
            client.setPostData(cast(void[])params.toString,"application/json");
            break;
    }
    client.onReceive = (ubyte[] data)
    {
        response.put(data);
        return data.length;
    };
    client.perform();                 // rely on curl to throw exceptions on 204, >=500
    return parseJSON(cast(string)response.data);
}


/**
    Retrieve information about the current account
    Parameters:
        VultrAPI -  API instance
    Returns:
        JSON in format:
        {
            "balance": "-5519.11",
            "pending_charges": "57.03",
            "last_payment_date": "2014-07-18 15:31:01",
            "last_payment_amount": "-1.00"
        }
*/

auto accountInfo(VultrAPI api)
{
    return api.request("account/info",HTTP.Method.get);
}

/**
    Retrieve a list of available applications. These refer to applications that can be launched when creating a Vultr VPS.
    Parameters:
        VultrAPI -  API instance
    Returns:
        JSON in format:
        {
            "1": {
                "APPID": "1",
                "name": "LEMP",
                "short_name": "lemp",
                "deploy_name": "LEMP on CentOS 6 x64",
                "surcharge": 0
            },
            "2": {
                "APPID": "2",
                "name": "WordPress",
                "short_name": "wordpress",
                "deploy_name": "WordPress on CentOS 6 x64",
                "surcharge": 0
            }
        }
*/    
auto accountInfo(VultrAPI api)
{
    return api.request("app/list",HTTP.Method.get);
}


/**
    Retrieve information about the current API key
    Parameters:
        VultrAPI -  API instance
    Returns:
        JSON in format:
        {
            "acls": [
                "subscriptions",
                "billing",
                "support",
                "provisioning"
            ],
            "email": "example@vultr.com",
            "name": "Example Account"
        }
*/
auto authInfo(VultrAPI api)
{
    return api.request("auth/info",HTTP.Method.get);
}


/**
    List all backups on the current account.
    Parameters:
        VultrAPI -  API instance
    Returns:
        JSON in format:
        {
            "543d34149403a": {
                "BACKUPID": "543d34149403a",
                "date_created": "2014-10-14 12:40:40",
                "description": "Automatic server backup",
                "size": "42949672960",
                "status": "complete"
            },
            "543d340f6dbce": {
                "BACKUPID": "543d340f6dbce",
                "date_created": "2014-10-13 16:11:46",
                "description": "",
                "size": "10000000",
                "status": "complete"
            }
        }
*/
auto backupsList(VultrAPI api)
{
    return api.request("backup/list",HTTP.Method.get);
}



/**
    List all backups on the current account.
    Parameters:
        VultrAPI -  API instance
    Returns:
        HTTP Result Code
*/
auto attachBlockStorage(VultrAPI api, int blockStorageID, int vpsID)
{
    // FIXME "--data 'SUBID=%s'" "--data 'attach-to=%s",blockStorageID,vpsID
    return api.request("backup/list",HTTP.Method.post);
}

/**
    Create a block storage subscription.
    Parameters:
        VultrAPI -  API instance
        DataCentre - data centre to create this subscription in - see /v1/regions/list
        int sizeGB - integer size in GB of this subscription
        string label - optional string text label to be associated with this subscription

    Returns:
        JSON in format:
        {
            "USERID": "564a1a88947b4",
            "api_key": "AAAAAAAA"
        }
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/block/create --data 'DCID=1' --data 'size_gb=50' --data 'label=test
auto createBlockStorageSubscription(VultrAPI api, DataCentre dataCentre, int sizeGB, string label="")
{
    return api.request("block/create",HTTP.Method.post);
}

/**
    Delete a block storage subscription.  All data will be permanently lost.  There is no going back from this call
    Parameters:
        VultrAPI -  API instance
        int blockStorageID- blockStorageID of the block storage subscription to delete
    Returns:
        HTTP Result Code
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/block/delete --data 'SUBID=1313217
auto deleteBlockStorageSubscription(VultrAPI api, int blockStorageID)
{
    return api.request("block/create",HTTP.Method.delete_);
}


/**
    Detach a block storage subscription from the currently attached instance.
    Parameters:
        VultrAPI -  API instance
        int blockStorageID- blockStorageID of the block storage subscription to delete

    Returns:
        HTTP Result Code
*/
///curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/block/detach --data 'SUBID=1313217
auto detachBlockStorageSubscription(VultrAPI api, int blockStorageID)
{
    return api.request("block/detach",HTTP.Method.post);
}


/**
    Set the label of a block storage subscription.
    Parameters:
        VultrAPI -  API instance
        int blockStorageID - blockStorageID of the block storage subscription to set the label for
        string lavel - label to set

    Returns:
        HTTP Result Code
*/
///curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/block/label_set --data 'SUBID=1313217' --data 'label=example'
auto setBlockStorageLabel(VultrAPI api, int blockStorageID, string label)
{
    return api.request("block/label_set",HTTP.Method.post);
}

/**
    Retrieve a list of any active block storage subscriptions on this account.
    Parameters:
        VultrAPI -  API instance
        int blockStorageID - optional blockStorageID of the block storage subscription to check active state
        
    Returns:
        JSON in format:
        [
            {
                "SUBID": 1313216,
                "date_created": "2016-03-29 10:10:04",
                "cost_per_month": 10,
                "status": "pending",
                "size_gb": 100,
                "DCID": 1,
                "attached_to_SUBID": null,
                "label": "files1"
            },
            {
                "SUBID": 1313217,
                "date_created": "2016-31-29 10:10:48",
                "cost_per_month": 5,
                "status": "active",
                "size_gb": 50,
                "DCID": 1,
                "attached_to_SUBID": 1313207,
                "label": "files2"
            }
        ]
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/block/list
auto listActiveBlockStorageSubscriptions(VultrAPI api, int blockStorageID = -1)
{
    return api.request("block/list",HTTP.Method.get);
}

/**
    Resize the block storage volume to a new size.
    WARNING: When shrinking the volume, you must manually shrink the filesystem and partitions beforehand, or you will lose data.

    Parameters:
        VultrAPI -  API instance
        int blockStorageID - blockStorageID of the block storage subscription to set the label for
        int newSizeGB - new size in GB of block storage subscription

    Returns:
        HTTP Result Code
*/
///curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/block/label_set --data 'SUBID=1313217' --data 'label=example'
/// todo - safety check for size
auto resizeBlockStorage(VultrAPI api, int blockStorageID, int newSizeGB)
{
    return api.request("block/resize",HTTP.Method.post);
}


/**
    Create a domain name in DNS.

    Parameters:
        VultrAPI -  API instance
        string domain - domain name to create
        string serverIP - server IP to use when creating default records (A and MX)

    Returns:
        HTTP Result Code
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/dns/create_domain --data 'domain=example.com' --data 'serverip=127.0.0.1'
auto createDomainName(VultrAPI api, string domain, string serverIP)
{
    return api.request("dns/create_domain",HTTP.Method.post);
}

/**
    Delete a domain name and all associated records.

    Parameters:
        VultrAPI -  API instance
        string domain - domain name to create

    Returns:
        HTTP Result Code
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/dns/delete_domain --data 'domain=example.com'
auto deleteDomainName(VultrAPI api, string domain)
{
    return api.request("dns/delete_domain",HTTP.Method.post);
}

/**
    Delete an individual DNS record

    Parameters:
        VultrAPI -  API instance
        string domain - domain name to delete record from
        int recordID - integer ID of record to delete from (see /dns/records)

    Returns:
        HTTP Result Code
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/dns/delete_record --data 'domain=example.com' --data 'RECORDID=1265277'
auto deleteDomainRecord(VultrAPI api, string domain, int recordID)
{
    return api.request("dns/delete_domain",HTTP.Method.post);
}

/**
    List all domains associated with the current account.
    Parameters:
        VultrAPI -  API instance
        
    Returns:
        JSON in format:
        [
            {
                "domain": "example.com",
                "date_created": "2014-12-11 16:20:59"
            }
        ]
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/dns/list
auto listAllDomains(VultrAPI api)
{
    return api.request("dns/list",HTTP.Method.get);
}


/**
    List all the records associated with a particular domain.
    Parameters:
        VultrAPI -  API instance
        string domain - domain to list records for

    Returns:
        JSON in format:
        [
            {
                "type": "A",
                "name": "",
                "data": "127.0.0.1",
                "priority": 0,
                "RECORDID": 1265276,
                "ttl": 300
            },
            {
                "type": "CNAME",
                "name": "*",
                "data": "example.com",
                "priority": 0,
                "RECORDID": 1265277,
                "ttl": 300
            }
        ]
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/dns/records?domain=example.com
auto listDomainRecords(VultrAPI api, string domain)
{
    return api.request("dns/records",HTTP.Method.get);
}


/**
    Update a DNS record

    Parameters:
        VultrAPI -  API instance
        string domain - Domain name to delete record from
        int recordID -  ID of record to delete (see /dns/records)
        string name - optional Name (subdomain) of record
        string data - optional Data for this record
        int ttl- (optional) TTL of this record
        int priority - (optional) (only required for MX and SRV) Priority of this record (omit the priority from the data)

    Returns:
        HTTP Result Code
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/dns/update_record --data 'domain=example.com' --data 'name=vultr' --data 'type=A' --data 'data=127.0.0.1'
auto updateDNSRecord(VultrAPI api, string domain, int recordID, string name="", string date="", int ttl = -1, int priority = -1)
{
    return api.request("dns/delete_domain",HTTP.Method.post);
}

/**
    List all ISOs currently available on this account.
    Parameters:
        VultrAPI -  API instance

    Returns:
        JSON in format:
        {
            "24": {
                "ISOID": 24,
                "date_created": "2014-04-01 14:10:09",
                "filename": "CentOS-6.5-x86_64-minimal.iso",
                "size": 9342976,
                "md5sum": "ec0669895a250f803e1709d0402fc411"
            }
        }
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/iso/list
auto listISOs(VultrAPI api)
{
    return api.request("iso/list",HTTP.Method.get);
}

/**
    Retrieve a list of available operating systems. If the "windows" flag is true, a Windows
    license will be included with the instance, which will increase the cost.

    Parameters:
        VultrAPI -  API instance

    Returns:
        JSON in format:
        {
            "127": {
                "OSID": "127",
                "name": "CentOS 6 x64",
                "arch": "x64",
                "family": "centos",
                "windows": false
            },
            "148": {
                "OSID": "148",
                "name": "Ubuntu 12.04 i386",
                "arch": "i386",
                "family": "ubuntu",
                "windows": false
            }
        }        {
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/os/list
auto listOperatingSystems(VultrAPI api)
{
    return api.request("os/list",HTTP.Method.get);
}

/**
    Retrieve a list of all active plans. Plans that are no longer available will not be shown.

    The "windows" field is no longer in use, and will always be false. Windows licenses will be automatically
    added to any plan as necessary.

    The "deprecated" field indicates that the plan will be going away in the future. New deployments of it
    will still be accepted, but you should begin to transition away from it's usage. Typically, deprecated
    plans are available for 30 days after they are deprecated.

    Parameters:
        VultrAPI -  API instance
        string type - optional type of plans to return: "all", "vc2", "ssd", "vdc2", "dedicated"

    Returns:
        JSON in format:
        {
            "1": {
                "VPSPLANID": "1",
                "name": "Starter",
                "vcpu_count": "1",
                "ram": "512",
                "disk": "20",
                "bandwidth": "1",
                "price_per_month": "5.00",
                "windows": false,
                "plan_type": "SSD",
                "available_locations": [
                    1,
                    2,
                    3
                ]
            },
            "2": {
                "VPSPLANID": "2",
                "name": "Basic",
                "vcpu_count": "1",
                "ram": "1024",
                "disk": "30",
                "bandwidth": "2",
                "price_per_month": "8.00",
                "windows": false,
                "plan_type": "SATA",
                "available_locations": [],
                "deprecated": true
            }
        }
*/
/// curl https://api.vultr.com/v1/plans/list?type=vc2
auto listActivePlans(VultrAPI api, string type="")
{
    return api.request("plans/list",HTTP.Method.get);
}

/**
    Retrieve a list of all active vc2 plans. Plans that are no longer available will not be shown.

    The 'deprecated' field indicates that the plan will be going away in the future. New deployments
    of it will still be accepted, but you should begin to transition away from it's usage. Typically,
    deprecated plans are available for 30 days after they are deprecated.

    Parameters:
        VultrAPI -  API instance

    Returns:
        JSON in format:
        {
            "1": {
                "VPSPLANID": "1",
                "name": "Starter",
                "vcpu_count": "1",
                "ram": "512",
                "disk": "20",
                "bandwidth": "1",
                "price_per_month": "5.00",
                "plan_type": "SSD"
            }
        }
*/
/// curl https://api.vultr.com/v1/plans/list?type=vc2
auto listActiveVC2Plans(VultrAPI api)
{
    return api.request("plans/list_vc2",HTTP.Method.get);
}


/**
    Retrieve a list of all active vdc2 plans. Plans that are no longer available will not be shown.

    The 'deprecated' field indicates that the plan will be going away in the future. New deployments
    of it will still be accepted, but you should begin to transition away from it's usage. Typically,
    deprecated plans are available for 30 days after they are deprecated.

    Parameters:
        VultrAPI -  API instance

    Returns:
        JSON in format:
        {
            "115": {
                "VPSPLANID": "115",
                "name": "8192 MB RAM,110 GB SSD,10.00 TB BW",
                "vcpu_count": "2",
                "ram": "8192",
                "disk": "110",
                "bandwidth": "10.00",
                "price_per_month": "60.00",
                "plan_type": "DEDICATED"
            }
        }
        */
/// curl https://api.vultr.com/v1/plans/list?type=vdc2
auto listActiveVDC2Plans(VultrAPI api)
{
    return api.request("plans/list_vdc2",HTTP.Method.get);
}


/**
    Retrieve a list of the VPSPLANIDs currently available in this location.

    Parameters:
        VultrAPI -  API instance
        DataCentre dataCentre - dataCentre location to get list for
    Returns:
        JSON in format:
        [
            40,
            11,
            45,
            29,
            41,
            61
        ]
*/

/// curl https://api.vultr.com/v1/regions/availability?DCID=1
auto listRegionsAvailability(VultrAPI api, DataCentre dataCentre)
{
    return api.request("regions/availability",HTTP.Method.get);
}


/**
    Retrieve a list of all active regions. Note that just because a region is listed here, does not mean that there is room for new servers.

    Parameters:
        VultrAPI -  API instance

    Returns:
        JSON in format:
        {
            "1": {
                "DCID": "1",
                "name": "New Jersey",
                "country": "US",
                "continent": "North America",
                "state": "NJ",
                "ddos_protection": true,
                "block_storage": true,
                "regioncode": "EWR"
            },
            "2": {
                "DCID": "2",
                "name": "Chicago",
                "country": "US",
                "continent": "North America",
                "state": "IL",
                "ddos_protection": false,
                "block_storage": false,
                "regioncode": "ORD"
            }
        }
*/

/// curl https://api.vultr.com/v1/regions/list
auto listActiveRegions(VultrAPI api)
{
    return api.request("regions/list",HTTP.Method.get);
}

/**
    Attach a reserved IP to an existing subscription.

    Parameters:
        VultrAPI -  API instance
        string reservedIP - Reserved IP to attach to your account (use the full subnet here)
        int serverID -  Unique indentifier of the server to attach the reserved IP to

    Returns:
        HTTP Result Code
*/
/// curl -H 'API-Key: EXAMPLE' https://api.vultr.com/v1/reservedip/attach --data 'ip_address=2001:db8:8000::/64' --data 'attach_SUBID=5342543
auto attachReservedIP(VultrAPI api, string reservedIP, int serverID)
{
    return api.request("reservedip/attach",HTTP.Method.post);
}

/**
=================================================================================================
*/

// List all Actions
auto listActions(VultrAPI api)
{
    return api.request("actions",HTTP.Method.get);
}

// retrieve existing Action
auto retrieveAction(VultrAPI api, string id)
{
    return api.request("actions/"~id, HTTP.Method.get);
}

auto allNeighbours(VultrAPI api)
{
    return api.request("reports/droplet_neighbors",HTTP.Method.get);
}

auto listUpgrades(VultrAPI api)
{
    return api.request("droplet_upgrades",HTTP.Method.get);    
}

// List all Domains (managed through Vultr DNS interface)
auto listDomains(VultrAPI api)
{
    return api.request("domains", HTTP.Method.get);
}

struct VultrDomain
{
    VultrAPI api;
    string id;
    alias id this;
    this(VultrAPI api, string id)
    {
        this.api=api;
        this.id=id;
    }
    // Create new Domain
    static auto create(VultrAPI api, string name, string ip)
    {
        JSONValue params;
        params["name"]=name;
        params["ip_address"]=ip;
        return api.request("domains", HTTP.Method.post, params);
    }
    auto request(string url, HTTP.Method method=HTTP.Method.get, JSONValue params=JSONValue(null))
    {
        return api.request(url,method,params);
    }
}

// Retrieve an existing Domain
auto get(VultrDomain domain)
{
    return domain.request("domains/"~domain.id, HTTP.Method.get);
}

 // Delete a Domain
auto del(VultrDomain domain)
{
    return domain.request("domains/"~domain.id, HTTP.Method.del);
}

//  List all Domain Records
auto listDomainRecords(VultrDomain domain)
{
    return domain.request(format("domains/%s/records",domain.id), HTTP.Method.get);
}

//  Create a new Domain Record
auto createRecord(VultrDomain domain, string rtype=null, string name=null, string data=null,
                         string priority=null, string port=null, string weight=null)
{
    JSONValue params;
    params["type"]=rtype;
    if(name.length>0)
        params["name"]=name;
    if(data.length>0)
        params["data"]=data;
    if(priority.length>0)
        params["priority"]=priority;
    if(port.length>0)
        params["port"]=port;
    if(weight.length>0)
        params["weight"]=weight;
    return domain.request(
        format("domains/%s/records",domain.id), HTTP.Method.post, params);
}

//  Retrieve an existing Domain Record
auto getRecord(VultrDomain domain, string recordId)
{
    return domain.request(
        format("domains/%s/records/%s",domain.id,recordId), HTTP.Method.get);
}

//  Delete a Domain Record
auto delRecord(VultrDomain domain, string recordId)
{
    return domain.request(
        format("domains/%s/records/%s",domain.id,recordId), HTTP.Method.del);
}

//  Update a Domain Record
auto updateRecord(VultrDomain domain, string recordId,string name)
{
    JSONValue params;
    params["name"] = name;
    return domain.request(format("domains/%s/records/%s",domain.id, recordId), HTTP.Method.put, params);
}


// list all droplets
auto listDroplets(VultrAPI api)
{
    return api.request("droplets",HTTP.Method.get);
}

enum VultrRegion
{
    ams2,
    ams3,
    fra1,
    lon1,
    nyc1,
    nyc2,
    nyc3,
    sfo1,
    sgp1,
    tor1,
}


immutable string[] VultrRegions;
VultrRegion oceanRegion(string region)
{
    VultrRegion ret;
    auto i=VultrRegions.countUntil(region);
    enforce(i>=0, new Exception("unknown droplet region: "~region));
    return cast(VultrRegion)i;
}

string toString(VultrRegion region)
{
    final switch(region) with(VultrRegion)
    {
        case ams2:
            return "Amsterdam 2";
        case ams3:
            return "Amsterdam 3";
        case fra1:
            return "Frankfurt 1";
        case lon1:
            return "London 1";
        case nyc1:
            return "New York 1";
        case nyc2:
            return "New York 2";
        case nyc3:
            return "New York 3";
        case sfo1:
            return "San Francisco 1";
        case sgp1:
            return "Singapore 1";
        case tor1:
            return "Toronto 1";
    }
    assert(0);
}

enum VultrDistro
{
    CoreOS,
    Debian,
    Fedora,
    CentOS,
    FreeBSD,
    Ubuntu,
}
alias VultrImageId=Algebraic!(int,string);
struct VultrGlobalImage
{
    bool isApplication=false;
    string slug;
    int id;
    VultrDistro distro;
    string application;
}
VultrGlobalImage[] VultrImages;


struct Droplet
{
    VultrAPI api;
    int id;

    this(VultrAPI api, int id)
    {
        this.api=api;
        this.id=id;
    }

    string toString()
    {
        return id.to!string;
    }
    auto request(string uri, HTTP.Method method=HTTP.Method.get, JSONValue params=JSONValue(null))
    {
        return api.request(uri,method,params);
    }

    //  Create a new Droplet
    static auto create(VultrAPI api,string name, VultrRegion region, string size, VultrImageId image, string[] sshKeys, string backups=null,
               string ipv6=null, string privateNetworking=null, string userData=null)
    {
        JSONValue params;
        params["name"]=name;
        params["region"]=region.to!string;
        params["size"]=size;
        if(image.type==typeid(string))
            params["image"]=image.get!string;
        else
            params["image"]=image.get!int;
        if (sshKeys.length>0)
            params["ssh_keys"]=sshKeys;
        if(backups.length>0)
            params["backups"]=backups.to!bool;
        if (ipv6.length>0)
            params["ipv6"]=ipv6.to!bool;
        if (privateNetworking.length>0)
            params["private_networking"]=privateNetworking.to!bool;
        if (userData.length>0)
            params["user_data"]=userData;
        return api.request("droplets", HTTP.Method.post, params);
    }
}

//  Makes an action
JSONValue action(Droplet droplet, DropletAction actionType,JSONValue params=JSONValue(null))
{
    params["type"]=actionType.toString;
    return droplet.request(format("droplets/%s/actions",droplet.id), HTTP.Method.post, params);
}

enum DropletAction
{
    reboot,
    powerCycle,
    shutdown,
    powerOff,
    powerOn,
    passwordReset,
    resize,
    restore,
    rebuild,
    rename,
    changeKernel,
    enableIPv6,
    disableBackups,
    enablePrivateNetworking,
    snapshot,
    upgrade,
}

string toString(DropletAction action)
{
    final switch(action) with(DropletAction)
    {
        case reboot:
            return "reboot";
        case powerCycle:
            return "power_cycle";
        case shutdown:
            return "shutdown";
        case powerOff:
            return "power_off";
        case powerOn:
            return "power_on";
        case passwordReset:
            return "password_reset";
        case resize:
            return "resize";
        case restore:
            return "restore";
        case rebuild:
            return "rebuild";
        case rename:
            return "rename";
        case changeKernel:
            return "change_kernel";
        case enableIPv6:
            return "enable_ipv6";
        case disableBackups:
            return "disable_backups";
        case enablePrivateNetworking:
            return "enable_private_networking";
        case snapshot:
            return "snapshot";
        case upgrade:
            return "upgrade";
    }
}


immutable string[] DropletActions;
DropletAction dropletAction(string action)
{
    auto i=DropletActions.countUntil(action);
    enforce(i>=0,new Exception("unknown droplet action: "~action));
    return cast(DropletAction)i;
}

struct VultrResult(T)
{
    bool found;
    T result;
}
// find droplet ID from anme
VultrResult!Droplet findDroplet(VultrAPI ocean, string name)
{
    auto ret=ocean.Droplet(-1);
    auto dropletResults=ocean.listDroplets;
    auto droplets="droplets" in dropletResults;
    enforce(droplets !is null, new Exception("bad response from Vultr: "~dropletResults.prettyPrint));
    enforce((*droplets).type==JSON_TYPE.ARRAY, new Exception
        ("bad response from Vultr: "~dropletResults.prettyPrint));
    (*droplets).array.each!(a=>enforce(("name" in a.object) && a.object["name"].type==JSON_TYPE.STRING));
    auto i=(*droplets).array.map!(a=>a.object["name"].str).array.countUntil(name);
    if (i==-1)
    {
        return VultrResult!Droplet(false,ret);
    }
    //auto p=("id" in ((*droplets).array[i]));
    //enforce(p !is null, new Exception
      //  ("findDroplet cannot find id in results - malformed JSON?\n"~dropletResults.prettyPrint));
    return VultrResult!Droplet(true,ocean.Droplet((*droplets).array[i].object["id"].integer.to!int));
}

//  List all available Kernels for a Droplet
auto kernels(Droplet droplet)
{
    return droplet.request(format("droplets/%s/kernels",droplet.id), HTTP.Method.get);
}


//  Retrieve snapshots for a Droplet
auto snapshots(Droplet droplet)
{
    return droplet.request(format("droplets/%s/snapshots",droplet.id), HTTP.Method.get);
}

//  Retrieve backups for a Droplet
auto backups(Droplet droplet)
{
  return droplet.request(format("droplets/%s/backups",droplet.id), HTTP.Method.get);
}

//  Retrieve actions for a Droplet
auto actions(Droplet droplet)
{
    return droplet.request(format("droplets/%s/actions",droplet.id), HTTP.Method.get);
}

//  Retrieve an existing Droplet by id
auto retrieve(Droplet droplet)
{
    return droplet.request("droplets/"~droplet.id.to!string, HTTP.Method.get);
}

//  Delete a Droplet
auto del(Droplet droplet)
{
    return droplet.request("droplets/"~droplet.id.to!string, HTTP.Method.del);
}

auto neighbours(Droplet droplet)
{
    return droplet.request(format("droplets/%s/neighbors",droplet.id),HTTP.Method.get);
}

//  Reboot a Droplet
auto reboot(Droplet droplet)
{
    return droplet.action(DropletAction.reboot);
}

//  Power Cycle a Droplet
auto powerCycle(Droplet droplet)
{
    return droplet.action(DropletAction.powerCycle);
}

//  Shutdown a Droplet
auto shutdown(Droplet droplet)
{
    return droplet.action(DropletAction.shutdown);
}

//  Power Off a Droplet
auto powerOff(Droplet droplet)
{
    return droplet.action(DropletAction.powerOff);
}

//  Power On a Droplet
auto powerOn(Droplet droplet)
{
    return droplet.action(DropletAction.powerOn);
}

//  Password Reset a Droplet
auto passwordReset(Droplet droplet)
{
    return droplet.action(DropletAction.passwordReset);
}

//  Resize a Droplet
auto resize(Droplet droplet, string size)
{
    JSONValue params;
    params["size"]=size;
    return droplet.action(DropletAction.resize, params);
}

//  Restore a Droplet
auto restore(Droplet droplet, string image)
{
    JSONValue params;
    params["image"]=image;
    return droplet.action(DropletAction.restore, params);
}

//  Rebuild a Droplet
auto rebuild(Droplet droplet, string image)
{
    JSONValue params;
    params["image"]=image;
    return droplet.action(DropletAction.rebuild, params);
}

//  Rename a Droplet
auto rename(VultrAPI api, Droplet droplet, string name)
{
    JSONValue params;
    params["name"]=name;
    return droplet.action(DropletAction.rename,params);
}

//  Change the Kernel
auto changeKernel(Droplet droplet, string kernel)
{
    JSONValue params;
    params["kernel"]=kernel;
    return droplet.action(DropletAction.changeKernel, params);
}

//  Enable IPv6
auto enableIPv6(Droplet droplet)
{
    return droplet.action(DropletAction.enableIPv6);
}

//  Disable Backups
auto disableBackups(Droplet droplet)
{
    return droplet.action(DropletAction.disableBackups);
}

//  Enable Private Networking
auto enablePrivateNetworking(Droplet droplet)
{
    return droplet.action(DropletAction.enablePrivateNetworking);
}

//  Snapshot
auto doSnapshot(Droplet droplet, string name=null)
{
    JSONValue params;
    if (name.length>0)
        params["name"]=name;
    return droplet.action(DropletAction.snapshot, params);
}

//  Retrieve a Droplet Action
auto retrieveAction(Droplet droplet, string actionId)
{
    return droplet.request(
        format("droplets/%s/actions/%s",droplet.id, actionId), HTTP.Method.get);
}

auto upgrade(Droplet droplet)
{
    JSONValue params;
    params["upgrade"]=true;
    droplet.action(DropletAction.upgrade,params);
}
struct VultrImage
{
    VultrAPI api;
    string id;
    alias id this;
    this(VultrAPI api, string id)
    {
        this.api=api;
        this.id=id;
    }
    auto request(string uri, HTTP.Method method=HTTP.Method.get, JSONValue params=JSONValue(null))
    {
        return api.request(uri,method,params);
    }
}
// List all images
auto listImages(VultrAPI api)
{
    return api.request("images", HTTP.Method.get);
}

// Retrieve an existing Image by id or slug
auto get(VultrImage image)
{
    return image.request("images/"~image.id, HTTP.Method.get);
}

//  Delete an Image
auto del(VultrImage image)
{
    return image.request("images/"~image.id, HTTP.Method.del);
}

//  Update an Image
auto update(VultrImage image, string name)
{
    JSONValue params;
    params["name"]=name;
    return image.request("images/"~image.id, HTTP.Method.put, params);
}

//  Transfer an Image
auto transfer(VultrImage image, VultrRegion region)
{
    JSONValue params;
    params["type"]="transfer";
    params["region"]=region.to!string;
    return image.request(format("images/%s/actions",image.id), HTTP.Method.post,params);
}

 // Retrieve an existing Image Action

auto getImageAction(VultrImage image, string actionId)
{
    return image.request(format("images/%s/actions/%s",image.id,actionId), HTTP.Method.get);
}

struct VultrKey
{
    VultrAPI api;
    string value;

    this(VultrAPI api,string key)
    {
        this.api=api;
        this.value=key;
    }
    auto request(string uri, HTTP.Method method=HTTP.Method.get, JSONValue params=JSONValue(null))
    {
        return api.request(uri,method,params);
    }

    // Create a new Key
    static auto create(VultrAPI api, string name, string publicKey)
    {
        JSONValue params;
        params["name"]=name;
        params["public_key"]=publicKey;
        return api.request("account/keys", HTTP.Method.post, params);
    }
}

// list all keys
auto listKeys(VultrAPI api)
{
    return api.request("account/keys", HTTP.Method.get);
}


// Retrieve an existing Key by Id or Fingerprint

auto retrieve(VultrKey key)
{
    return key.request("account/keys/"~key.value, HTTP.Method.get);
}

//  Update an existing Key by Id or Fingerprint
auto updateName(VultrKey key, string name)
{
    JSONValue params;
    params["name"]=name;
    return key.request("account/keys/"~key.value, HTTP.Method.put, params);
}

//  Destroy an existing Key by Id or Fingerprint
auto del(VultrKey key)
{
    return key.request("account/keys/"~key.value, HTTP.Method.del);
}


// list all regions
auto listRegions(VultrAPI api)
{
   return api.request("regions", HTTP.Method.get);
}

// list all sizes
auto listSizes(VultrAPI api)
{
    return api.request("sizes", HTTP.Method.get);
}
