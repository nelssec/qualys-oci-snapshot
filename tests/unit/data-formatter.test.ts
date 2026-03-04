import {
  formatInstanceToInventory,
  formatVolumeAttachment,
  createScanStatusRecord,
  chunkArray,
  generateBackupDisplayName,
} from '../../functions/shared/lib/data-formatter';

describe('Data Formatter', () => {
  describe('formatInstanceToInventory', () => {
    it('should format an OCI instance to inventory item', () => {
      const instance = {
        id: 'ocid1.instance.oc1.iad.test123',
        compartmentId: 'ocid1.compartment.oc1..abc',
        availabilityDomain: 'Uocm:US-ASHBURN-AD-1',
        displayName: 'test-instance',
        lifecycleState: 'RUNNING',
        shape: 'VM.Standard.E4.Flex',
        sourceDetails: { imageId: 'ocid1.image.oc1.iad.img123' },
        timeCreated: '2024-01-01T00:00:00.000Z',
        freeformTags: { env: 'prod' },
        definedTags: {},
      };

      const result = formatInstanceToInventory(instance, [], 'ocid1.tenancy.oc1..xyz');

      expect(result.resourceId).toBe('ocid1.instance.oc1.iad.test123');
      expect(result.resourceType).toBe('instance');
      expect(result.platform).toBe('LINUX');
      expect(result.state).toBe('RUNNING');
      expect(result.tenancyId).toBe('ocid1.tenancy.oc1..xyz');
      expect(result.UID).toBeTruthy();
      expect(result.ExpiresAt).toBeGreaterThan(0);
    });

    it('should detect Windows platform', () => {
      const instance = {
        id: 'ocid1.instance.oc1.iad.win123',
        compartmentId: 'ocid1.compartment.oc1..abc',
        availabilityDomain: 'Uocm:US-ASHBURN-AD-1',
        displayName: 'windows-server-2022',
        lifecycleState: 'RUNNING',
        shape: 'VM.Standard.E4.Flex',
        sourceDetails: { imageId: 'ocid1.image.oc1.iad.img123' },
        timeCreated: '2024-01-01T00:00:00.000Z',
        freeformTags: {},
        definedTags: {},
      };

      const result = formatInstanceToInventory(instance, [], 'ocid1.tenancy.oc1..xyz');
      expect(result.platform).toBe('WINDOWS');
    });
  });

  describe('formatVolumeAttachment', () => {
    it('should format boot volume attachment', () => {
      const attachment = {
        id: 'ocid1.bootvolumeattachment.oc1.iad.att123',
        bootVolumeId: 'ocid1.bootvolume.oc1.iad.vol123',
        availabilityDomain: 'Uocm:US-ASHBURN-AD-1',
        sizeInGBs: 50,
        freeformTags: {},
      };

      const result = formatVolumeAttachment(attachment, 'boot');
      expect(result.volumeType).toBe('boot');
      expect(result.volumeId).toBe('ocid1.bootvolume.oc1.iad.vol123');
      expect(result.sizeInGBs).toBe(50);
    });

    it('should format block volume attachment', () => {
      const attachment = {
        id: 'ocid1.volumeattachment.oc1.iad.att456',
        volumeId: 'ocid1.volume.oc1.iad.vol456',
        availabilityDomain: 'Uocm:US-ASHBURN-AD-1',
        sizeInGBs: 100,
        kmsKeyId: 'ocid1.key.oc1.iad.key123',
        freeformTags: {},
      };

      const result = formatVolumeAttachment(attachment, 'block');
      expect(result.volumeType).toBe('block');
      expect(result.isEncrypted).toBe(true);
      expect(result.kmsKeyId).toBe('ocid1.key.oc1.iad.key123');
    });
  });

  describe('createScanStatusRecord', () => {
    it('should create a PENDING scan status', () => {
      const result = createScanStatusRecord('res-123', 'VULN', 'us-ashburn-1', 'LINUX');
      expect(result.status).toBe('PENDING');
      expect(result.ResourceId).toBe('res-123');
      expect(result.ScanType).toBe('VULN');
      expect(result.backupIds).toEqual([]);
    });
  });

  describe('chunkArray', () => {
    it('should chunk an array', () => {
      const arr = [1, 2, 3, 4, 5];
      expect(chunkArray(arr, 2)).toEqual([[1, 2], [3, 4], [5]]);
    });

    it('should handle empty array', () => {
      expect(chunkArray([], 5)).toEqual([]);
    });

    it('should handle chunk size larger than array', () => {
      expect(chunkArray([1, 2], 10)).toEqual([[1, 2]]);
    });
  });

  describe('generateBackupDisplayName', () => {
    it('should generate a meaningful backup name', () => {
      const name = generateBackupDisplayName('ocid1.instance.oc1.iad.abc123', 'boot', 'VULN');
      expect(name).toContain('snapshot-boot-VULN');
      expect(name).toContain('abc123');
    });
  });
});
