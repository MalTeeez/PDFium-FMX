// DEPENDENCIES
import { readFileSync, existsSync, statSync} from 'fs';
import express from 'express';
import crypto from 'crypto';
import fileupload from 'express-fileupload';
const app = express();
const port = `5001`;
import cors from 'cors';

//DECLARE GLOBAL VARS
var items = []; 
var temp_dir = 'tmp';
var file_dir = 'files';
var last_update = -1;
var timeout_next = 1000;


// LOAD LIBRARIES
app.use(cors()).use(express.json()).use(fileupload({
    useTempFiles : false,
    tempFileDir : temp_dir,
    safeFileNames : /[ &\/\\#,+()$~%'":*?<>{}]/g, //remove bad chars from file name
    preserveExtension : 3,

}));

function updateTimestamp() {
    last_update = Date.now();
    //if (_timeout) timeout_next = _timeout;
}

function removeItemById(id) {
    items.forEach(item => {
        if (item.id === id) {
            const index = items.indexOf(item);
            if (index > -1) {
                items.splice(index, 1);
            }
        }
    });
}

function getItemById(id) {
    items.forEach(item => {
        if (item.id === id) {
            const index = items.indexOf(item);
            if (index > -1) {
                return item;
            }
        }
    });
}

function getItemsByName(name) {
    let res = [];
    items.forEach(item => {
        if (item.name === name) {
            const index = items.indexOf(item);
            if (index > -1) {
                res.push(item);
            }
        }
    });
    return res;
}

async function getStringHash(type, name, created_at) {
    const uin8array = new TextEncoder().encode('PPRLSS::'+type+name+created_at);
    const hashBuffer = await crypto.subtle.digest('SHA-256', uin8array);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map((h) => h.toString(16).padStart(2, '0')).join('');
}

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
    constructor(type, name, created_at, updated_at, file_name, file_location, file_size, file_hash) {
        this.type = type;
        this.name = name;
        this.created_at = created_at;
        this.updated_at = updated_at;
        getStringHash(type, name, created_at).then(id => {
            this.id = id;
        });
        this.file_name = file_name;
        this.file_location = file_location;
        this.file_size = file_size;
        this.file_hash = file_hash;

    }

    setFileName(file_name) {
        this.file_name = file_name;
    }

    setFileLocation(file_location) {
        this.file_name = file_location;
    }

    rehash() {
        getHashFromPath(this.file_location + '/' + this.file_name).then(hash => {
            this.file_hash = hash;
        });
    }

    setSize() {
        this.file_size = statSync(file_path).size;
    }

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
            let ftype = JSON.stringify(req.query.file).replace(/[ &\/\\#,+()$~%'":*?<>{}]/g, "").match(/(?<=\.)([\w]+)$/g)[0].toLowerCase();
            if (req.query.file && fileTypes.includes(ftype)) {
                return resolve(JSON.stringify(req.query.file).replace(/[ &\/\\#,+()$~%'":*?<>{}]/g, "")); //Remove unallowed fs chars
            } else {
                return reject(`Please provide a file type of ?file=${fileTypes.join('|')}`);}
        });
        const file_path = await new Promise((resolve_1, reject_1) => {
            if (existsSync(file_dir + file)) {
                return resolve_1(file_dir + file);
            }
            return reject_1(`File '${file}' was not found.`);
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
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items', async(_req, res) => { 
    try {
        res.status(200).json({items, hashsum : await getStringHash(JSON.stringify(items)), total : items.length});
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}.`,
        });
    }
});

app.get('/items/delete', async(req, res) => {
    try {
        removeItemById(req.query.id);
        updateTimestamp();
        res.status(200).send({
            message: `Item with Id ${req.query.id} was successfully deleted.`,
        });
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}.`,
        });
    }
});

app.get('/items/update', async(_req, res) => {
    try {
        updateTimestamp();
        res.status(200).send({
            message: ''
        });
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}.`,
        });
    }
});

app.post('/items/create', async(req, res) => {
    try {
        if (!req.body.type || !req.body.name || !req.body.created_at || !req.body.updated_at) {
            return res.status(400).send('Encountered error while processing item creation: Missing params. Consult /items/template');    
        }
        if (!req.files || Object.keys(req.files).length === 0) {
            return res.status(400).send('Encountered error while processing upload: No files provided.');
        }

        let file_hash = await getHashFromFile(Array.from(req.files.file.data));
        //console.log('Our Hash: \t' + file_hash + '\nTheir Hash: \t' + req.body.file_hash);
        if (!(file_hash == req.body.file_hash)) {
            return res.status(400).send('Encountered error while processing upload: File didn' +"'"+ 't match provided checksum: ' 
                + req.body.file_hash + '. ');
        }
        req.files.file.mv(file_dir + '/' + req.files.file.name);
        createAndLoadToItems(req.body.type, req.body.name, req.body.created_at, 
                             req.body.updated_at, req.files.file.name, file_dir, req.files.file.size, file_hash);
        updateTimestamp();
        res.status(200).send({
            message: `Item with Name ${req.body.name} and File ${req.files.file.name} was successfully created.`,
        });
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/template', async(_req, res) => {
    try {
        res.status(200).json({templates : ['container', 'document', 'item']});
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/template/container', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/container.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/template/document', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/document.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/template/file', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/file.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

async function main() {
    var jsonItems = JSON.parse(readFileSync('./items/items.json').toString());
    await jsonItems.items.forEach((element) => loadToItems(element)); 
}

await main();

// HTTP SERVER
app.listen(port, () => console.log(`Listening on port ${port}`));