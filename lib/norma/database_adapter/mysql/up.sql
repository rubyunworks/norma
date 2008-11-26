/* Sequence for object ids. (Use uuids instead?) */

CREATE SEQUENCE obj_sequence;

/* Every object has an entry in the obj table.
 * If the object is a core-class object, then it will also
 * have an entry in one of the obj* class tables with the 
 * same id.
 */

/* Should class allow NULL? */

CREATE TABLE obj (
  id         int,
  class      text    NULL,
  PRIMARY KEY (id)
);

CREATE TABLE objFixnum (
  id         int,
  value      int,
  PRIMARY KEY (id)
);

CREATE TABLE objSymbol (
  id         int,
  value      text,
  PRIMARY KEY (id)
);

CREATE TABLE objString (
  id         int,
  value      text,
  PRIMARY KEY (id)
);

CREATE TABLE objFloat (
  id         int,
  value      float,
  PRIMARY KEY (id)
);

CREATE TABLE objRange (
  id         int,
  begins     numeric,
  ends       numeric,
  exclusive  bool,
  PRIMARY KEY (id)
);

CREATE TABLE objTime (
  id         int,
  value      timestamp,
  PRIMARY KEY (id)
);

CREATE TABLE objArray (
  id         int,
  values     int[],
  PRIMARY KEY (id)
);

CREATE TABLE objHash (
  id         int,
  keys       int[],
  values     int[],
  PRIMARY KEY (id)
);

/*** 
 *** Instance Variable Table. All instance
 *** variables are stored in this table.
 ***/
CREATE TABLE ivar (
  name          text   NOT NULL,
  obj_id        int    REFERENCES obj(id),
  val_id        int    REFERENCES obj(id),
  PRIMARY KEY (obj_id, name)
);

CREATE INDEX ivar_obj_index ON ivar(obj_id);


