import request from 'supertest';
import { expect } from 'chai';
import app from '../app.mjs';

describe('Inventory API', () => {
    describe('GET /inventory', () => {
        it('should return all inventory items', (done) => {
            request(app)
                .get('/inventory')
                .expect(200)
                .end((err, res) => {
                    if (err) return done(err);
                    expect(res.body).to.be.an('array');
                    expect(res.body.length).to.equal(10);
                    done();
                });
        });
    });

    describe('GET /inventory/:id', () => {
        it('should return the item with the given id', (done) => {
            request(app)
                .get('/inventory/1')
                .expect(200)
                .end((err, res) => {
                    if (err) return done(err);
                    expect(res.body).to.be.an('object');
                    expect(res.body).to.have.property('id', '1');
                    done();
                });
        });

        it('should return 404 if the item is not found', (done) => {
            request(app)
                .get('/inventory/999')
                .expect(404)
                .end((err, res) => {
                    if (err) return done(err);
                    expect(res.body).to.have.property('error', 'Item not found');
                    done();
                });
        });
    });
});
