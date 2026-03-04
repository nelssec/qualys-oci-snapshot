import { NOSQL_TABLES, QUEUES, TAGS, MAX_CONCURRENT_BACKUPS, OCI_REGIONS } from '../../functions/shared/lib/constants';

describe('Constants', () => {
  it('should have 5 NoSQL tables defined', () => {
    expect(Object.keys(NOSQL_TABLES)).toHaveLength(5);
  });

  it('should have 6 queues defined', () => {
    expect(Object.keys(QUEUES)).toHaveLength(6);
  });

  it('should have correct tag values', () => {
    expect(TAGS.APP_TAG_KEY).toBe('App');
    expect(TAGS.APP_TAG_VALUE).toBe('snapshot-scanner');
  });

  it('should limit concurrent backups to 10', () => {
    expect(MAX_CONCURRENT_BACKUPS).toBe(10);
  });

  it('should have OCI regions defined', () => {
    expect(OCI_REGIONS.length).toBeGreaterThan(20);
    expect(OCI_REGIONS).toContain('us-ashburn-1');
  });
});
