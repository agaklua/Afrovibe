export type Relation<T> = T | T[] | null | undefined;
export function one<T>(value:Relation<T>):T|null{return value==null?null:Array.isArray(value)?value[0]??null:value as T;}
export function rows<T>(value:unknown):T[]{return Array.isArray(value)?value as T[]:[];}
