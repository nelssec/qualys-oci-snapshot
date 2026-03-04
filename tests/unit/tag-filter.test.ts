import { shouldIncludeResource, shouldIncludeVolume, filterResources } from '../../functions/shared/lib/tag-filter';
import type { TagsConfig } from '../../functions/shared/lib/types';

describe('Tag Filter', () => {
  const defaultConfig: TagsConfig = {
    mustHaveTags: '',
    anyInListTags: '',
    noneInTheList: '',
    noneOnVolume: '',
    qualysTags: 'App=snapshot-scanner',
  };

  describe('shouldIncludeResource', () => {
    it('should include resource when no filters configured', () => {
      const resource = { freeformTags: { env: 'prod' } };
      expect(shouldIncludeResource(resource, defaultConfig)).toBe(true);
    });

    it('should include when all mustHave tags present', () => {
      const config = { ...defaultConfig, mustHaveTags: 'env=prod,team=infra' };
      const resource = { freeformTags: { env: 'prod', team: 'infra', other: 'value' } };
      expect(shouldIncludeResource(resource, config)).toBe(true);
    });

    it('should exclude when mustHave tags missing', () => {
      const config = { ...defaultConfig, mustHaveTags: 'env=prod,team=infra' };
      const resource = { freeformTags: { env: 'prod' } };
      expect(shouldIncludeResource(resource, config)).toBe(false);
    });

    it('should include when any anyInList tag present', () => {
      const config = { ...defaultConfig, anyInListTags: 'env=prod,env=staging' };
      const resource = { freeformTags: { env: 'staging' } };
      expect(shouldIncludeResource(resource, config)).toBe(true);
    });

    it('should exclude when no anyInList tags present', () => {
      const config = { ...defaultConfig, anyInListTags: 'env=prod,env=staging' };
      const resource = { freeformTags: { env: 'dev' } };
      expect(shouldIncludeResource(resource, config)).toBe(false);
    });

    it('should exclude when noneInTheList tag matches', () => {
      const config = { ...defaultConfig, noneInTheList: 'skip=true,temp=yes' };
      const resource = { freeformTags: { skip: 'true' } };
      expect(shouldIncludeResource(resource, config)).toBe(false);
    });

    it('should include when no noneInTheList tags match', () => {
      const config = { ...defaultConfig, noneInTheList: 'skip=true' };
      const resource = { freeformTags: { env: 'prod' } };
      expect(shouldIncludeResource(resource, config)).toBe(true);
    });

    it('should handle combined filters', () => {
      const config: TagsConfig = {
        mustHaveTags: 'managed=true',
        anyInListTags: 'env=prod,env=staging',
        noneInTheList: 'skip=true',
        noneOnVolume: '',
        qualysTags: '',
      };
      const resource = { freeformTags: { managed: 'true', env: 'prod' } };
      expect(shouldIncludeResource(resource, config)).toBe(true);
    });
  });

  describe('shouldIncludeVolume', () => {
    it('should include when no volume filter configured', () => {
      const volume = { freeformTags: { encrypted: 'false' } };
      expect(shouldIncludeVolume(volume, defaultConfig)).toBe(true);
    });

    it('should exclude volume matching noneOnVolume', () => {
      const config = { ...defaultConfig, noneOnVolume: 'exclude=true' };
      const volume = { freeformTags: { exclude: 'true' } };
      expect(shouldIncludeVolume(volume, config)).toBe(false);
    });
  });

  describe('filterResources', () => {
    it('should filter a list of resources', () => {
      const config = { ...defaultConfig, mustHaveTags: 'scan=yes' };
      const resources = [
        { freeformTags: { scan: 'yes', name: 'a' } },
        { freeformTags: { scan: 'no', name: 'b' } },
        { freeformTags: { scan: 'yes', name: 'c' } },
      ];
      const result = filterResources(resources, config);
      expect(result).toHaveLength(2);
    });
  });
});
