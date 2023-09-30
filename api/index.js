// DEPENDENCIES
import { readFileSync, existsSync, statSync} from 'fs';
import express from 'express';
import crypto from 'crypto';
import fileupload from 'express-fileupload';
const app = express();
const port = '5001';
import cors from 'cors';

//DECLARE GLOBAL VARS
var items = []; 
const temp_dir = 'tmp';
const file_dir = 'files';
var last_update = -1;
var timeout_next = 1000;
const error_msg = 'Encountered error while processing request: ';

// LOAD LIBRARIES
app.use(cors()).use(express.json()).use(fileupload({
    useTempFiles : false,
    tempFileDir : temp_dir,
    safeFileNames : /[ &\/\\#,+()$~%'":*?<>{}]/g, //remove bad chars from file name
    preserveExtension : 3,

}));

function updateTimestamp(_timeout) {
    last_update = Date.now();
    if (_timeout) timeout_next = _timeout;
}


function getCurrentTimeString() {
    return new Date().toLocaleString('de-DE', { hour: '2-digit', minute: '2-digit', 
        day: '2-digit', month: '2-digit', year: 'numeric', 
        hour12: false, timeZone: 'Europe/Athens'})
        .replace(/\./g, '/');
}

/**
 * Tries to remove an item by its Id
 * @param {string} id The to be removed items Id
 * @returns {boolean} Whether an item was deleted or not
 */
function removeItemById(id) {
    for (const item of items) {
        if (item.id === id) {
            const index = items.indexOf(item);
            if (index > -1) {
                items.splice(index, 1);
                return true;
            }
        }
    };
    return false;
}

/**
 * Tries to remove an item by its Id
 * @param {string} id The to be found items Id
 * @returns {*} The item if one was found, otherwise "false"
 */
function getItemById(id) {
    for (const item of items) {
        if (item.id === id) {
            const index = items.indexOf(item);
            if (index > -1) {
                return item;
            }
        }
    };
    return false;
}

/**
 * Searches for items with a name
 * @param {string} name The items name to be found
 * @returns {*} A list of items that were found by name
 */
function getItemsByName(name) {
    let res = [];
    for (const item of items) {
        if (item.name === name) {
            const index = items.indexOf(item);
            if (index > -1) {
                res.push(item);
            }
        }
    };
    return res;
}

/**
 * Update an items params
 * @param {*} id The Id of the item to be updated
 * @param {*} new_params An object with optional: type, name, created_at, updated_at attributes
 * @returns False if the item could'nt be updated or the items (new) Id if it was updated (It will be different if type, name or created_at were changed)
 */
async function updateParamsByItemId(id, new_params) {
    let item = getItemById(id);
    if (item) {
        if (new_params.type) item.setType(new_params.type);
        if (new_params.name) item.setName(new_params.name);
        if (new_params.created_at) item.setCreatedAt(new_params.created_at);
        if (new_params.updated_at) item.setType(new_params.updated_at);
        return await item.reValId();
    } else return false;
}

/**
 * Update an items file
 * @param {string} id The Id of the item to be updated
 * @param {string} file_name The name of the new file
 * @param {string} file_dir The location of the new file
 * @param {string} file_size The Size of the new file
 * @param {string} file_hash The SHA-256 hash of the new file
 * @returns {boolean} Whether or not the item was updated
 */
function updateFileByItemId(id, file_name, file_dir, file_size, file_hash) {
    let item = getItemById(id);
    if (item) {
        item.setFileName(file_name);
        item.setFileDir(file_dir);
        item.setFileSize(file_size);
        item.setFileHash(file_hash);   
        return true;  
    } else return false;
}

/**
 * Generates a Paperless item Id
 * @param {string} p1 Param 1
 * @param {string} p2 Param 2
 * @param {string} p3 Param 3
 * @returns The generated item Id as a string
 */
async function digestID(p1, p2, p3) {
    const uin8array = new TextEncoder().encode('PPRLSS::'+ p1 + p2 + p3);
    const hashBuffer = await crypto.subtle.digest('SHA-256', uin8array);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map((h) => h.toString(16).padStart(2, '0')).join('');
}

/**
 * Generates a SHA-256 hash from a string
 * @param {string} string The input text
 * @returns The generated hash as a string
 */
async function getHashFromString(string) {
    const uin8array = new TextEncoder().encode(string);
    const hashBuffer = await crypto.subtle.digest('SHA-256', uin8array);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map((h) => h.toString(16).padStart(2, '0')).join('');
}

/**
 * Generates a SHA-256 hash from a file stored on disk
 * @param {*} file Byte buffer array
 * @returns A SHA-256 hash as a string
 */
async function getHashFromPath(file_path) {
    let file = readFileSync(file_path);
    //Load file from path and convert contents into UInt8Array
    const uin8array = new Uint8Array(file);
    //Compute sha-256 hash from UInt8Array into a new UInt8Array
    const hashBuffer = await crypto.subtle.digest('SHA-256', uin8array);
    //Convert the UInt8Array back into a bit array
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    //Convert the bit array back into a string and return the promise for that
    return hashArray.map((h) => h.toString(16).padStart(2, '0')).join('');
}

/**
 * Generates a loaded files SHA-256 hash
 * @param {*} file Byte buffer array
 * @returns A SHA-256 hash as a string
 */
async function getHashFromFile(file) {
    const uin8array = new Uint8Array(file);
    //Compute sha-256 hash from UInt8Array into a new UInt8Array
    const hashBuffer = await crypto.subtle.digest('SHA-256', uin8array);
    //Convert the UInt8Array back into a bit array
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    //Convert the bit array back into a string and return the promise for that
    return hashArray.map((h) => h.toString(16).padStart(2, '0')).join('');
}

class itemObject {
    /**
     * Creates a new item object
     * @param {string} type Type of item, should be one of [container, document, file]
     * @param {string} name Name of item to be shown in UI's
     * @param {string} created_at Creation timestamp, has to be a format of "DD/MM/YYYY, HH:mm"
     * @param {string} updated_at Last update timestamp, has to be a format of "DD/MM/YYYY, HH:mm"
     * @param {string} file_name Item file name, has to be be unix & windows compliant
     * @param {string} file_location Item file location, without "/" at start or end of string
     * @param {integer} file_size The item file size, in bytes
     * @param {string} file_hash Item file hash, of type SHA-256
     * 
     * @returns The newly created item object
     */
    constructor(type, name, created_at, updated_at, file_name, file_location, file_size, file_hash) {
        this.type = type;
        this.name = name;
        this.created_at = created_at;
        this.updated_at = updated_at;
        digestID(type, name, created_at).then(id => {
            this.id = id;
        });
        this.file_name = file_name;
        this.file_location = file_location;
        this.file_size = file_size;
        this.file_hash = file_hash;

        return this;
    }

    /**
     * Sets the items type
     * @WARNING It is highly recommended to reevaluate the items Id after 
     * changing this attribute, since this property is a part of that.
     * @param {string} type Type of item, should be one of [container, document, file]
     */
    setType(type) {
        this.type = type;
    }

    /**
     * Sets the items name
     * @WARNING It is highly recommended to reevaluate the items Id after 
     * changing this attribute, since this property is a part of that.
     * @param {string} name Name of item to be shown in UI's
     */
    setName(name) {
        this.name = name;
    }

    /**
     * Sets the items creation timestamp
     * @WARNING It is highly recommended to reevaluate the items Id after 
     * changing this attribute, since this property is a part of that.
     * @param {string} created_at Creation timestamp, has to be a format of "DD/MM/YYYY, HH:mm"
     */
    setCreatedAt(created_at) {
        this.created_at = created_at;
    }

    /**
     * Sets the items last update
     * @param {string} updated_at Last update timestamp, has to be a format of "DD/MM/YYYY, HH:mm"
     */
    setUpdatedAt(updated_at) {
        this.updated_at = updated_at;
    }

    /**
     * Sets the last updated timestamp to the current time
     */
    setUpdatedAtToNow() {
        this.updated_at = getCurrentTimeString();
    }

    /**
     * Sets the items file name
     * @param {string} created_at Item file name, has to be be unix & windows compliant
     */
    setFileName(file_name) {
        this.file_name = file_name;
    }

    /**
    * Sets the items file location
    * INFO: Currently always the same directory, since that could be a potential security issue
    * @param {string} file_location Item file location, without "/" at start or end of string
    */
    setFileLocation(file_location) {
        this.file_name = file_location;
    }

    /**
     * Reevaluates the items Id using the currently set item type, name and creation timestamp
     * @returns The reevaluated item Id
     */
    async reValId() {
        const id = await digestID(this.type, this.name, this.created_at)
        this.id = id;
        return id;
    }

    /**
     * Sets the items file hash.
     * @WARNING Only use this if you 100% know your provided hash matches the currently assigned file for this item,
     * otherwise use reValHash()
     * @param {string} file_hash Item file hash, of type SHA-256
     */
    setFileHash(file_hash) {
        this.file_size = file_hash;
    }

    /**
     * Reevaluates the items file hash using the currently set item file
     * @returns {string} The reevaluated item file hash, of type SHA-256
     */
    async reValHash() {
        const hash = await getHashFromPath(this.file_location + '/' + this.file_name)
        this.file_hash = hash;
        return hash;
    }

    /**
    * Sets the items file size.
    * @WARNING Only use this if you 100% know your provided file size matches the currently assigned file for this item,
    * otherwise use reValSize()
    * @param {integer} file_size The item file size, in bytes
    */
    setFileSize(size) {
        this.file_size = size;
    }

    /**
    * Reevaluates the items file size using the currently set item file
    * @returns {integer} The reevaluated item file size, in bytes
    */
    reValSize() {
        this.file_size = statSync(file_path).size;
        return this.file_size;
    }

    /**
     * @returns The item in a JSON string format
     */
    toString() {
        return JSON.stringify(obj);
    }
}


function loadToItems(obj) {
    items.push( new itemObject(obj.type, obj.name, obj.created_at, obj.updated_at, obj.file_name, obj.file_location));
}

function createAndLoadToItems(type, name, created_at, updated_at, file_name, file_location, file_size, file_hash) {
    items.push( new itemObject(type, name, created_at, updated_at, file_name, file_location, file_size, file_hash));
}

// API ENDPOINTS
app.get('/file', async (req, res) => {
    const fileTypes = [
        "pdf"
    ];

    console.log('Got File API Request for ' + JSON.stringify(req.query));
    // Check if the right request is coming through for the file type
    try {
        const file = await new Promise((resolve, reject) => {q
            let ftype = JSON.stringify(req.query.file)
                .replace(/[ &\/\\#,+()$~%'":*?<>{}]/g, "")
                .match(/(?<=\.)([\w]+)$/g)[0]
                .toLowerCase();
            if (req.query.file && fileTypes.includes(ftype)) {
                return resolve(JSON.stringify(req.query.file)
                    .replace(/[ &\/\\#,+()$~%'":*?<>{}]/g, "")); //Remove unallowed fs chars
            } else {
                return reject(error_msg + 'Please provide a file type of ?file=' + fileTypes.join('|') + '.')}
        });
        const file_path = await new Promise((resolve_1, reject_1) => {
            if (existsSync(file_dir + file)) {
                return resolve_1(file_dir + file);
            }
            return reject_1(error_msg + 'File with name:' + {file} + ' was not found.');
        });
        res.download(file_path);
    } catch (e) {
        res.status(400).send(e);
    }
});

app.get('/last-update', async(_req, res) => {
    try {
        res.status(200).json({'last_update' : last_update, 'timeout_next' : timeout_next});
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.get('/items', async(_req, res) => { 
    try {
        res.status(200).json({items, hashsum : await getHashFromString(JSON.stringify(items)), total : items.length});
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.get('/items/delete', async(req, res) => {
    try {
        if (!req.query.id) {
            return res.status(400).send(error_msg + 'No Item Id provided.');
        }
        if (removeItemById(req.query.id)) {
            res.status(200).send({
                message: 'Item with Id ' + req.query.id + ' was successfully deleted.',
            });
        } else {
            return res.status(400).send(error_msg + 'Item with Id ' + req.query.id + ' could not be found.');
        }
        updateTimestamp();
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.post('/items/update/params', async(req, res) => {
    try {
        if (!req.query.id) {
            return res.status(400).send(error_msg + 'No Item Id provided.');
        }
        const id = await updateParamsByItemId(req.query.id, req.body);
        if (id) {
            res.status(200).json({
                message: 'Params for Item with Id ' + req.query.id + ' were successfully updated.',
                new_id: id 
            });
        } else {
            return res.status(400).send(error_msg + 'Item with Id ' + req.query.id + ' could not be found.');
        }
        updateTimestamp();
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.post('/items/update/file', async (req, res) => {
    try {
        if (!req.query.id) {
            return res.status(400).send(error_msg + 'No Item Id provided.');
        } else if (!req.files || Object.keys(req.files).length === 0) { 
            return res.status(400).send(error_msg + 'No files provided.');
        }

        let file_hash = await getHashFromFile(Array.from(req.files.file.data));
        if (!(file_hash == req.body.file_hash)) {
            return res.status(400).send(error_msg + 'File didn' + "'" + 't match provided checksum: '
                + req.body.file_hash + '. ');
        }

        req.files.file.mv(file_dir + '/' + req.files.file.name);   
        if (updateFileByItemId(req.query.id, )) {

        } else {
            return res.status(400).send(error_msg + 'Item with Id ' + req.query.id + ' could not be found.');
        }
        updateTimestamp();
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.post('/items/create', async(req, res) => {
    try {
        if (!req.body.type || !req.body.name || !req.body.created_at || !req.body.updated_at) {
            return res.status(400).send(error_msg + 'Missing params. Consult /items/template');    
        }
        if (!req.files || Object.keys(req.files).length === 0) {
            return res.status(400).send(error_msg + 'No files provided.');
        }

        let file_hash = await getHashFromFile(Array.from(req.files.file.data));
        //console.log('Our Hash: \t' + file_hash + '\nTheir Hash: \t' + req.body.file_hash);
        if (!(file_hash == req.body.file_hash)) {
            return res.status(400).send(error_msg + 'File didn' +"'"+ 't match provided checksum: ' 
                + req.body.file_hash + '. ');
        }
        req.files.file.mv(file_dir + '/' + req.files.file.name);
        createAndLoadToItems(req.body.type, req.body.name, req.body.created_at, 
                             req.body.updated_at, req.files.file.name, file_dir, req.files.file.size, file_hash);
        updateTimestamp();
        res.status(200).send({
            message: 'Item with Name ' + req.body.name + ' and File ' + req.files.file.name + ' was successfully created.',
        });
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.get('/items/template', async(_req, res) => {
    try {
        res.status(200).json({templates : ['container', 'document', 'item']});
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.get('/items/template/container', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/container.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.get('/items/template/document', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/document.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

app.get('/items/template/file', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/file.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: error_msg + e,
        });
    }
});

async function main() {
    var jsonItems = JSON.parse(readFileSync('./items/items.json').toString());
    await jsonItems.items.forEach((element) => loadToItems(element)); 
}

app.get('*', async(_req, res) => {
    console.log('Got Request for root.');
    res.status(200).send('<!doctype html> <html lang="en"><head><title>Paperless API</title><meta charset="utf-8">' + 
        '<br><br><br><p style = "text-align:center" ><span style="font-family:Tahoma,Geneva,sans-serif"><strong><span style="font-size:48px"><span style="color:#4e5f70">Success! </span></span></strong></span><span style="font-size:48px">🐬</span></p >' +
        '<p style="text-align:center"><span style="font-family:Tahoma,Geneva,sans-serif"><span style="font-size:48px"><span style="color:#4e5f70">Using <u>Paperless</u>-API, Version<em> </em><em>1.0</em></span></span></span></p></html>')
});

await main();

// HTTP SERVER
app.listen(port, () => console.log('Listening on port ' + port));